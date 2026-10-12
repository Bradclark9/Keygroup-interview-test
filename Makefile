# Keygroup Platform - Makefile
# One environment: prod, running on the floci-gcp emulator. Usage: make help

NAMESPACE  := keygroup
RELEASE    := keygroup-api
HELM_CHART := ./helm/keygroup-api
IMAGE_NAME := keygroup-api
IMAGE_TAG  := prod-$(shell date +%Y%m%d%H%M%S)
# Run from app/; CI passes PYTHON=python
PYTHON     ?= .venv/bin/python
TF         := terraform -chdir=$(CURDIR)/terraform

# Must match terraform/terraform.tfvars (project_id, name_prefix) and the backend in terraform/versions.tf
PROJECT     := keygroup-prod
CLUSTER     := kg-prod-gke
STATE_BUCKET := keygroup-prod-tfstate

# floci-gcp emulator
FLOCI_ENDPOINT  := http://localhost:4588
FLOCI_CONTAINER := keygroup-floci-gcp
FLOCI_COMPOSE   := docker compose -f docker-compose.floci.yml
K3S             := floci-gcp-gke-$(PROJECT)-$(CLUSTER)
KUBECONFIG_FILE := $(CURDIR)/.floci/kubeconfig
KUBECTL         := KUBECONFIG=$(KUBECONFIG_FILE) kubectl

.PHONY: help up down emulator infra seed kubeconfig deploy integration-test smoke-test load-test slo-check \
	lint test k8s-status k8s-logs k8s-port-forward

help:
	@echo "Keygroup Platform: prod on GKE (floci-gcp emulator)"
	@echo ""
	@echo "  make up                - Emulator + terraform + app, nginx, Prometheus, Grafana"
	@echo "  make down              - Remove the emulator, cluster and all state"
	@echo "  make k8s-port-forward  - App :8080, nginx :8081, Grafana :3000, Prometheus :9090"
	@echo ""
	@echo "Tests (also the CI pipeline stages, see .github/workflows/ci.yml):"
	@echo "  make lint              - terraform fmt/validate + helm lint"
	@echo "  make test              - Python unit tests"
	@echo "  make integration-test  - App + real GCS client against floci (after make up)"
	@echo "  make smoke-test        - App, nginx, Grafana answer; Prometheus scrapes the app"
	@echo "  make load-test         - fortio load (LOAD_QPS=100 LOAD_DURATION=2m)"
	@echo "  make slo-check         - Fail unless success and within-300ms are >= 99.99%"
	@echo ""
	@echo "  make k8s-status | k8s-logs"

# ============================================================
# Deploy: terraform + helm against the floci-gcp emulator
# ============================================================

up: deploy
	@echo ""
	@echo "=== prod is up ==="
	@echo "  make smoke-test         # check it"
	@echo "  make k8s-port-forward   # then open http://localhost:3000 (Grafana SLO dashboard)"

emulator:
	$(FLOCI_COMPOSE) up -d --wait
	curl -sf -o /dev/null $(FLOCI_ENDPOINT)/storage/v1/b/$(STATE_BUCKET) || \
		curl -sf -o /dev/null -X POST "$(FLOCI_ENDPOINT)/storage/v1/b?project=$(PROJECT)" \
			-H 'Content-Type: application/json' -d '{"name":"$(STATE_BUCKET)"}'

infra: emulator
	$(TF) init -input=false -reconfigure
	$(TF) apply -input=false -auto-approve

seed: infra
	for f in app/sample-data/users/user-1/files/*; do \
		curl -sf -o /dev/null -X POST --data-binary @$$f \
			-H "Content-Type: $$(file --mime-type -b $$f)" \
			"$(FLOCI_ENDPOINT)/upload/storage/v1/b/$$($(TF) output -raw customer_files_bucket)/o?uploadType=media&name=users/user-1/files/$$(basename $$f)"; \
	done

# floci-gcp runs the GKE cluster as a k3s container; point its kubeconfig at the published port
kubeconfig: infra
	mkdir -p $(dir $(KUBECONFIG_FILE))
	for i in $$(seq 60); do docker exec $(K3S) test -s /etc/rancher/k3s/k3s.yaml && break; sleep 2; done
	docker exec $(K3S) cat /etc/rancher/k3s/k3s.yaml \
		| sed "s#127.0.0.1:6443#127.0.0.1:$$(docker port $(K3S) 6443/tcp | head -1 | cut -d: -f2)#" \
		> $(KUBECONFIG_FILE)
	for i in $$(seq 60); do $(KUBECTL) get nodes -o name 2>/dev/null | grep -q node && break; sleep 2; done
	$(KUBECTL) wait --for=condition=Ready nodes --all --timeout=180s

# No registry: the image is imported straight into k3s. Pods reach floci-gcp by IP via a hostAlias.
deploy: seed kubeconfig
	docker build -t $(IMAGE_NAME):$(IMAGE_TAG) ./app
	docker save $(IMAGE_NAME):$(IMAGE_TAG) | docker exec -i $(K3S) ctr -n k8s.io images import -
	KUBECONFIG=$(KUBECONFIG_FILE) helm upgrade --install $(RELEASE) $(HELM_CHART) \
		-n $(NAMESPACE) --create-namespace \
		--set image.tag=$(IMAGE_TAG) \
		--set gcsBucket=$$($(TF) output -raw customer_files_bucket) \
		--set gcpServiceAccount=$$($(TF) output -raw file_service_sa_email) \
		--set flociIP=$$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' $(FLOCI_CONTAINER)) \
		--wait --timeout=300s

# The k3s container keeps cluster state in a named volume (plus anonymous ones); remove
# them too, or the next `make up` revives the old cluster next to a dead node.
down:
	docker rm -f -v $(K3S) 2>/dev/null || true
	docker volume rm -f $(K3S) >/dev/null
	$(FLOCI_COMPOSE) down -v
	rm -rf $(dir $(KUBECONFIG_FILE))

# ============================================================
# Tests: each target is one stage of the CI pipeline
# ============================================================

lint:
	$(TF) fmt -check -recursive
	$(TF) init -input=false -backend=false
	$(TF) validate
	helm lint $(HELM_CHART) --set gcsBucket=lint --set flociIP=127.0.0.1

test:
	cd app && $(PYTHON) -m pytest -q

# The real google-cloud-storage code path against floci's GCS API (needs `make up` first)
integration-test:
	cd app && GCS_BUCKET=$$($(TF) output -raw customer_files_bucket) STORAGE_EMULATOR_HOST=$(FLOCI_ENDPOINT) \
		$(PYTHON) -m pytest -q -m integration

# Through the Kubernetes API service proxy, so no port-forward is needed
SVC_PROXY := /api/v1/namespaces/$(NAMESPACE)/services
smoke-test:
	$(KUBECTL) get --raw $(SVC_PROXY)/$(RELEASE):80/proxy/v1/users/user-1/files/profile.json && echo
	$(KUBECTL) get --raw $(SVC_PROXY)/$(RELEASE)-nginx:80/proxy/ | grep -o '<title>.*</title>'
	$(KUBECTL) get --raw $(SVC_PROXY)/grafana:3000/proxy/api/health | grep '"database": "ok"'
	for i in $$(seq 30); do \
		$(KUBECTL) get --raw '$(SVC_PROXY)/prometheus:9090/proxy/api/v1/query?query=up%7Bapp%3D%22$(RELEASE)%22%7D' \
			| grep -q '"1"\]' && echo "prometheus: scraping $(RELEASE)" && exit 0; sleep 2; \
	done; echo "prometheus: $(RELEASE) not scraped"; exit 1

# Steady load from inside the cluster. 99.99% needs >= 10,000 requests to mean anything.
LOAD_QPS      ?= 100
LOAD_DURATION ?= 2m
load-test:
	$(KUBECTL) -n $(NAMESPACE) run loadtest --rm -i --restart=Never --image=fortio/fortio:1.75.3 -- \
		load -qps $(LOAD_QPS) -t $(LOAD_DURATION) -c 8 -p "50,99,99.9,99.99" \
		http://$(RELEASE)/v1/users/user-1/files/profile.json

# SLO gate on what Prometheus recorded. An expression with a `>= target` filter returns
# nothing when the SLO is breached, so no "=>" in promtool's output means fail.
SLO_TARGET   := 0.9999
SLO_WINDOW   := 15m
PROMQL       := $(KUBECTL) -n $(NAMESPACE) exec deploy/prometheus -- promtool query instant http://localhost:9090
SUCCESS_RATE := sum(increase(http_requests_total{status!~"5.."}[$(SLO_WINDOW)])) / sum(increase(http_requests_total[$(SLO_WINDOW)]))
WITHIN_300MS := sum(increase(http_request_duration_seconds_bucket{le="0.3"}[$(SLO_WINDOW)])) / sum(increase(http_request_duration_seconds_count[$(SLO_WINDOW)]))
slo-check:
	sleep 10 # let Prometheus scrape the end of the load test
	$(PROMQL) '$(SUCCESS_RATE) >= $(SLO_TARGET)' | grep '=>' \
		|| { echo "SLO breached: success rate"; $(PROMQL) '$(SUCCESS_RATE)'; exit 1; }
	$(PROMQL) '$(WITHIN_300MS) >= $(SLO_TARGET)' | grep '=>' \
		|| { echo "SLO breached: within 300ms"; $(PROMQL) '$(WITHIN_300MS)'; exit 1; }

# ============================================================
# Kubernetes helpers
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
