# Keygroup: customer file retrieval service

A Python (FastAPI) service that returns customer files from Google Cloud Storage, running on GKE that's provisioned with Terraform. Everything runs locally on **[floci-gcp](https://floci.io)**, a GCP emulator, so no Google Cloud account is needed.

**Architecture diagram:** [docs/architecture.drawio](docs/architecture.drawio) (open it at [app.diagrams.net](https://app.diagrams.net)). Page 1 is the production design, and page 2 is what runs locally.

## Prerequisites

Docker (running), Terraform ≥ 1.5, kubectl and Helm 3.

```bash
brew install --cask docker && brew install terraform kubectl helm
```

floci itself is a Docker image (`floci/floci-gcp`), and it's pulled automatically.

## Run

```bash
make up           # ~2 min first run: emulator → terraform apply → seed data → build → helm deploy
```

```bash
make k8s-port-forward    # keep running, then in another terminal:

curl http://localhost:8080/v1/users/user-1/files/profile.json   # the API
open http://localhost:3000                                       # Grafana SLO dashboard (no login)
open http://localhost:8081                                       # nginx welcome page
```

```bash
make smoke-test         # check the app, nginx, Grafana and Prometheus
make load-test          # 100 req/s for 2 min, watch it in Grafana
make slo-check          # fails unless both SLOs are >= 99.99%
make test               # unit tests (no cluster needed)
make integration-test   # app + real GCS client against floci
make down               # tear everything down
```

`make help` lists every command.

### Grafana

1. Run `make k8s-port-forward` and leave it running.
2. Open **http://localhost:3000**. There's no login, and it opens on the **Keygroup API SLOs** dashboard (also under Dashboards → Keygroup).
3. In another terminal, run `make load-test`. The dashboard refreshes every 5s and stays mostly empty until there's traffic.

The dashboard shows the success rate and % of responses within 300ms against the 99.99% targets, the error budget left for each, requests per second by status code, and latency percentiles (p50/p99/p99.9) with the 300ms line.

**Page won't load?** Check that the port-forward is still running, that the stack is up (`make up`), and that nothing else is using port 3000 (`lsof -i :3000`).

## What's in it

| Part | What it does |
|------|--------------|
| **Terraform** (`terraform/`) | VPC and subnet, a private regional GKE cluster with Workload Identity and Shielded Nodes, least-privilege service accounts, a locked-down versioned GCS bucket, Artifact Registry. On floci the state is stored in the emulator's GCS. |
| **Service** (`app/`) | `GET /v1/users/{id}/files/{file}` reads from GCS. Strict ID validation blocks path traversal. It exposes `/metrics` for Prometheus and writes one JSON log line per request. |
| **Helm** (`helm/keygroup-api/`) | The app (non-root, read-only filesystem, health probes), nginx, Prometheus and Grafana with a pre-built SLO dashboard. |
| **CI** (`.github/workflows/ci.yml`) | A staged pipeline on every push, with no cloud credentials: lint and unit tests → deploy prod → smoke test → integration tests → load test → SLO gate. Each stage is one `make` target, and there's a marked place to add more test stages. |

**SLOs** are 99.99% success and 99.99% of responses within 300ms. The latency histogram has a bucket at exactly 0.3s, so "within 300ms" is an exact count rather than an estimate. A 12,000-request load test gives **100% success and 99.992% within 300ms (p99.99 231ms)**, so `make slo-check` passes. Each pod caches hot files for 30s (`CACHE_TTL_SECONDS`), which hides storage latency spikes; without it the run reached only 99.85%, because floci's storage emulator stalls for ~1s about once per 1,000 calls. The load test reads one file, so it measures the cache-hit path.

## How it runs on floci

- `terraform/terraform.tfvars` sets `emulator_endpoint`, which points the Google provider at floci. Leave it empty and the same code targets real GCP.
- floci doesn't emulate Cloud NAT or Artifact Registry, so both are switched off in `terraform.tfvars`.
- floci runs the GKE cluster as a k3s container. The Makefile pulls its kubeconfig and imports the app image directly, with no registry.
- Pods reach floci's storage API through a `floci-gcp` host alias (`STORAGE_EMULATOR_HOST`).

## Assumptions and trade-offs

- **Cloud Storage, not the brief's Compute Disk.** Persistent Disk is zonal and can only be mounted read-write by one pod, so it can't serve 6,000 req/s across zones. Cloud Storage scales reads, versions objects, and can hand out signed URLs for large files.
- **One environment: prod.** It runs on floci, with resources named `kg-prod-*` in project `keygroup-prod`. To move it to real GCP, clear `emulator_endpoint`, set a real project, and point the backend at a real GCS bucket. Extra environments would each get their own tfvars and state prefix.
- **One uvicorn worker per pod.** This keeps the Prometheus counters accurate; you scale by adding replicas.
- **What's built vs planned.** The diagram marks built items with ✓. Planned pieces (auth, caching, Cloud SQL metadata, Pub/Sub upload processing, tracing) are listed in docs/NEXT_STEPS.txt.

## Next steps

See [docs/NEXT_STEPS.txt](docs/NEXT_STEPS.txt) for what I'd add and the tools I'd use: auth, latency SLO improvements, more test stages, security hardening, tracing and alerting, and moving prod to real GCP.
