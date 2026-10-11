# Keygroup Platform - Makefile
# Usage: make help

NAMESPACE  := keygroup
RELEASE    := keygroup-api
HELM_CHART := ./helm/keygroup-api
IMAGE_NAME := keygroup-api
IMAGE_TAG  := floci-$(shell date +%Y%m%d%H%M%S)

# floci-gcp: names must match terraform.tfvars and the backend in versions.tf
FLOCI_ENDPOINT     := http://localhost:4588
FLOCI_PROJECT      := floci-local
FLOCI_CLUSTER      := kg-floci-gke
FLOCI_STATE_BUCKET := floci-tfstate
FLOCI_CONTAINER    := keygroup-floci-gcp
FLOCI_K3S          := floci-gcp-gke-$(FLOCI_PROJECT)-$(FLOCI_CLUSTER)
FLOCI_COMPOSE      := docker compose -f docker-compose.floci.yml
KUBECONFIG_FILE    := $(CURDIR)/.floci/kubeconfig
KUBECTL            := KUBECONFIG=$(KUBECONFIG_FILE) kubectl

.PHONY: help floci-up floci-down floci-start floci-infra floci-seed floci-kubeconfig \
	floci-deploy floci-test floci-load floci-logs lint test k8s-status k8s-logs k8s-port-forward

help:
	@echo "Keygroup Platform (GKE on the floci-gcp emulator)"
	@echo ""
	@echo "  make floci-up          - Emulator + terraform + app, nginx, observability on GKE (one command)"
	@echo "  make floci-down        - Remove the emulator, cluster and all state"
	@echo "  make k8s-port-forward  - App :8080, nginx :8081, Grafana :3000, Prometheus :9090"
	@echo "  make floci-load        - Load test (LOAD_QPS=100 LOAD_DURATION=2m), watch it in Grafana"
	@echo "  make floci-logs        - Latest request logs from Cloud Logging on floci"
	@echo "  make k8s-status        - Pods and services"
	@echo "  make k8s-logs          - Follow app logs"
	@echo "  make lint              - terraform fmt/validate + helm lint"
	@echo "  make test              - Python unit tests"

# ============================================================
# floci-gcp: terraform + helm against a local GCP emulator
# ============================================================

floci-up: floci-test
	@echo ""
	@echo "=== Done ==="
	@echo "  make k8s-port-forward   # then open http://localhost:3000 (Grafana SLO dashboard)"
	@echo "  make floci-load         # generate traffic"

floci-start:
	$(FLOCI_COMPOSE) up -d --wait
	curl -sf -o /dev/null $(FLOCI_ENDPOINT)/storage/v1/b/$(FLOCI_STATE_BUCKET) || \
		curl -sf -o /dev/null -X POST "$(FLOCI_ENDPOINT)/storage/v1/b?project=$(FLOCI_PROJECT)" \
			-H 'Content-Type: application/json' -d '{"name":"$(FLOCI_STATE_BUCKET)"}'

floci-infra: floci-start
	terraform init -input=false -reconfigure
	terraform apply -input=false -auto-approve

floci-seed: floci-infra
	for f in app/sample-data/users/user-1/files/*; do \
		curl -sf -o /dev/null -X POST --data-binary @$$f \
			-H "Content-Type: $$(file --mime-type -b $$f)" \
			"$(FLOCI_ENDPOINT)/upload/storage/v1/b/$$(terraform output -raw customer_files_bucket)/o?uploadType=media&name=users/user-1/files/$$(basename $$f)"; \
	done

# floci-gcp runs the GKE cluster as a k3s container; point its kubeconfig at the published port
floci-kubeconfig: floci-infra
	mkdir -p $(dir $(KUBECONFIG_FILE))
	for i in $$(seq 60); do docker exec $(FLOCI_K3S) test -s /etc/rancher/k3s/k3s.yaml && break; sleep 2; done
	docker exec $(FLOCI_K3S) cat /etc/rancher/k3s/k3s.yaml \
		| sed "s#127.0.0.1:6443#127.0.0.1:$$(docker port $(FLOCI_K3S) 6443/tcp | head -1 | cut -d: -f2)#" \
		> $(KUBECONFIG_FILE)
	$(KUBECTL) wait --for=condition=Ready nodes --all --timeout=180s

# No registry: the image is imported straight into k3s. Pods reach floci-gcp by IP via a hostAlias.
floci-deploy: floci-seed floci-kubeconfig
	docker build -t $(IMAGE_NAME):$(IMAGE_TAG) ./app
	docker save $(IMAGE_NAME):$(IMAGE_TAG) | docker exec -i $(FLOCI_K3S) ctr -n k8s.io images import -
	KUBECONFIG=$(KUBECONFIG_FILE) helm upgrade --install $(RELEASE) $(HELM_CHART) \
		-n $(NAMESPACE) --create-namespace \
		--set image.tag=$(IMAGE_TAG) \
		--set gcsBucket=$$(terraform output -raw customer_files_bucket) \
		--set gcpServiceAccount=$$(terraform output -raw file_service_sa_email) \
		--set flociIP=$$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' $(FLOCI_CONTAINER)) \
		--wait --timeout=180s

# Smoke test through the Kubernetes API service proxy: app, nginx and Grafana answer,
# Prometheus is scraping the app, and the app's request log reached Cloud Logging on floci.
TEST_SINCE := $(shell date -u +%Y-%m-%dT%H:%M:%SZ)
SVC_PROXY  := /api/v1/namespaces/$(NAMESPACE)/services
floci-test: floci-deploy
	$(KUBECTL) get --raw $(SVC_PROXY)/$(RELEASE):80/proxy/v1/users/user-1/files/profile.json && echo
	$(KUBECTL) get --raw $(SVC_PROXY)/$(RELEASE)-nginx:80/proxy/ | grep -o '<title>.*</title>'
	$(KUBECTL) get --raw $(SVC_PROXY)/grafana:3000/proxy/api/health | grep '"database": "ok"'
	for i in $$(seq 30); do \
		$(KUBECTL) get --raw '$(SVC_PROXY)/prometheus:9090/proxy/api/v1/query?query=up%7Bapp%3D%22$(RELEASE)%22%7D' \
			| grep -q '"1"\]' && echo "prometheus: scraping $(RELEASE)" && exit 0; sleep 2; \
	done; echo "prometheus: $(RELEASE) not scraped"; exit 1
	for i in $$(seq 30); do \
		curl -sf -X POST -H 'Content-Type: application/json' $(FLOCI_ENDPOINT)/v2/entries:list \
			-d '{"resourceNames":["projects/$(FLOCI_PROJECT)"],"orderBy":"timestamp desc","pageSize":1000,"filter":"logName=\"projects/$(FLOCI_PROJECT)/logs/stdout\" AND timestamp>=\"$(TEST_SINCE)\""}' \
			| grep -q 'profile.json' && echo "cloud logging: app request logs arriving" && exit 0; sleep 2; \
	done; echo "cloud logging: no app request logs"; exit 1

# Load test from inside the cluster at a steady rate. 99.99% needs >= 10,000 requests to mean anything.
# Watch it live in Grafana (make k8s-port-forward, http://localhost:3000).
LOAD_QPS      ?= 100
LOAD_DURATION ?= 2m
floci-load:
	$(KUBECTL) -n $(NAMESPACE) run loadtest --rm -i --restart=Never --image=fortio/fortio:1.75.3 -- \
		load -qps $(LOAD_QPS) -t $(LOAD_DURATION) -c 8 -p "50,99,99.9,99.99" \
		http://$(RELEASE)/v1/users/user-1/files/profile.json

# Latest app request logs from Cloud Logging on floci, i.e. `gcloud logging read 'logName=.../stdout'`.
# floci ignores resource-label filters, so the container filter happens here.
floci-logs:
	curl -sf -X POST -H 'Content-Type: application/json' $(FLOCI_ENDPOINT)/v2/entries:list \
		-d '{"resourceNames":["projects/$(FLOCI_PROJECT)"],"orderBy":"timestamp desc","pageSize":1000,"filter":"logName=\"projects/$(FLOCI_PROJECT)/logs/stdout\""}' \
		| python3 -c 'import json,sys; \
			entries = [e for e in json.load(sys.stdin).get("entries", []) if e["resource"]["labels"]["container_name"] == "api"]; \
			[print(e["timestamp"][:23], e["severity"].ljust(5), e["resource"]["labels"]["pod_name"], e["jsonPayload"]["message"]) for e in entries[:20] if "jsonPayload" in e]'

floci-down:
	docker rm -f $(FLOCI_K3S) 2>/dev/null || true
	$(FLOCI_COMPOSE) down -v
	rm -rf $(dir $(KUBECONFIG_FILE))

# ============================================================
# Checks
# ============================================================

lint:
	terraform fmt -check -recursive
	terraform init -input=false -backend=false
	terraform validate
	helm lint $(HELM_CHART) --set gcsBucket=lint --set flociIP=127.0.0.1

test:
	cd app && .venv/bin/python -m pytest -q

# ============================================================
# Kubernetes helpers (floci cluster)
# ============================================================

k8s-status:
	$(KUBECTL) get all -n $(NAMESPACE)

k8s-logs:
	$(KUBECTL) logs -n $(NAMESPACE) -l app=$(RELEASE) -f --tail=100

k8s-port-forward:
	trap 'kill 0' INT TERM; \
	$(KUBECTL) port-forward -n $(NAMESPACE) svc/$(RELEASE) 8080:80 & \
	$(KUBECTL) port-forward -n $(NAMESPACE) svc/$(RELEASE)-nginx 8081:80 & \
	$(KUBECTL) port-forward -n $(NAMESPACE) svc/grafana 3000:3000 & \
	$(KUBECTL) port-forward -n $(NAMESPACE) svc/prometheus 9090:9090 & \
	wait
