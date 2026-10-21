# TaskBoard — DevSecOps Capstone (Python)

**Author:** Krish Jaiswal · **Stack:** React · FastAPI · PostgreSQL · Docker · GitHub Actions · Trivy · GHCR · Terraform · AWS EKS · Helm · Argo CD · Prometheus · Grafana

TaskBoard is a small SaaS-style task-management app. It exists to carry a real application all the way from a developer
laptop to a monitored, autoscaled Kubernetes cluster on AWS. Every DevOps layer below has a job:

| Layer | What it guarantees |
|---|---|
| Pytest | broken code never becomes an image |
| Docker (multi-stage, non-root) | the same artefact runs on a laptop, in CI and in the cluster |
| GitHub Actions | every push to `main` is tested, built, scanned, published and deployed automatically |
| Trivy | images with fixable HIGH/CRITICAL CVEs are blocked before they reach the registry |
| GHCR + SHA tags | every running pod traces back to an exact commit |
| Terraform | the AWS network and EKS cluster are code: reviewable, repeatable, destroyable |
| Helm + Argo CD | one versioned package per environment; Git is the source of truth for what runs |
| Prometheus + Grafana | you can see request rate, latency, errors and scaling as they happen |

---

## 1. Architecture

```text
 Developer ── git push ──▶ GitHub (main)
                              │
                              ▼
                ┌──────── GitHub Actions ─────────────────────────────────────────────┐
                │ 1 test      pytest (16 tests, SQLite in-memory) + npm ci && vite build │
                │ 2 image     docker build ─▶ Trivy (HIGH/CRITICAL = fail) ─▶ push GHCR  │
                │             ghcr.io/venkat1701/taskboard-{backend,frontend}:<git-sha>  │
                │ 3 deploy    kind cluster ─▶ helm upgrade --install ─▶ smoke test       │
                │ 4 gitops    bump tags in helm/taskboard/values-prod.yaml [skip ci]     │
                └──────────────────────────────────────────────────────────────┬────────┘
                                                                               │ watches Git
   Terraform ─▶ AWS ap-south-1                                                 ▼
   ┌───────────────────────── VPC 10.20.0.0/16 ───────────────────────────────────────────┐
   │ public subnets ×2  (NAT GW, load balancer)                                           │
   │ private subnets ×2 ─ EKS 1.35 managed node group (2× t3.medium)                       │
   │                                                                                      │
   │   ns argocd       Argo CD ── syncs Helm chart ──▶ ns taskboard                         │
   │   ns traefik      Traefik Ingress Controller (AWS LB)                                 │
   │                       │  /      ─▶ frontend Service ─▶ Nginx + React  (2 pods)       │
   │                       │  /api   ─▶ backend  Service ─▶ FastAPI        (2–6 pods, HPA)│
   │                       │                                    │                        │
   │                       │                                    ▼                        │
   │                       │                         PostgreSQL (PVC on EBS gp3)         │
   │   ns monitoring   Prometheus ── ServiceMonitor scrapes /metrics ── Grafana dashboard   │
   └──────────────────────────────────────────────────────────────────────────────────────┘
```

Request path in the cluster: browser → Ingress → `/api/*` goes straight to FastAPI, everything else to Nginx serving the
React build. Inside Docker Compose (no Ingress) the Nginx container proxies `/api/*` to the backend instead, so the
browser only ever talks to one origin and never needs to know an internal hostname.

## 2. Repository layout

```text
.
├── backend/                 FastAPI service
│   ├── app/                 main.py (routes), models.py, schemas.py, db.py, config.py
│   ├── alembic/versions/    0001_create_tasks.py migration
│   ├── tests/               conftest.py (isolated test DB) + test_api.py (16 tests)
│   ├── Dockerfile           multi-stage, venv without pip, uid 10001
│   ├── requirements.txt     runtime deps (pinned)   requirements-dev.txt  + pytest
│   └── pytest.ini
├── frontend/                React 19 + Vite 8 SPA
│   ├── src/main.jsx, src/styles.css
│   ├── nginx.conf.template  SPA routing + /api reverse proxy (BACKEND_URL via envsubst)
│   └── Dockerfile           multi-stage: node:22 build → nginx-unprivileged runtime (uid 101, :8080)
├── docker-compose.yml       postgres + backend + frontend with health-gated start-up
├── .github/workflows/ci-cd.yml
├── terraform/               VPC + EKS (+ add-ons) — see terraform/README.md
├── k8s/                     namespace.yaml, storageclass-gp3.yaml (EKS bootstrap)
├── helm/taskboard/          chart: deployments, services, ingress, HPA, postgres, ServiceMonitor, dashboard
├── argocd/                  application.yaml + install.sh (GitOps)
├── monitoring/              kube-prometheus-stack values (Prometheus + Grafana)
├── scripts/                 local-up.sh / local-down.sh (k3d), smoke-test.sh, load-test.sh
├── troubleshooting/         deliberately broken manifests for the debugging lab
└── demo/                    presentation deck, evidence logs, demo video
```

## 3. Tech stack

| Area | Tools |
|---|---|
| Languages | Python 3.12, JavaScript (React 19 / JSX), HCL, YAML, Bash |
| Backend | FastAPI 0.156, SQLAlchemy 2.1, Alembic 1.20, Pydantic Settings, psycopg 3, prometheus-fastapi-instrumentator |
| Frontend | React 19, Vite 8, Nginx 1.29 (unprivileged) |
| Database | PostgreSQL 16 |
| Testing | pytest 9, FastAPI TestClient, in-memory SQLite |
| Containers | Docker, Docker Compose, BuildKit |
| CI/CD | GitHub Actions, GitHub Container Registry (GHCR), kind |
| Security | Trivy 0.75 image scanning, non-root containers, dropped Linux capabilities, Pod Security Admission |
| Infrastructure | Terraform 1.7+, AWS provider 6, AWS VPC, EKS 1.35, EBS CSI, EKS Pod Identity |
| Kubernetes | Helm 3/4, Traefik Ingress, HorizontalPodAutoscaler, metrics-server, Argo CD |
| Observability | kube-prometheus-stack (Prometheus Operator, Prometheus, Grafana), ServiceMonitor |
| Local cluster | k3d (k3s in Docker) |

## 4. The application

### API (FastAPI) — Swagger UI at `/docs`

| Method | Path | Purpose |
|---|---|---|
| GET | `/health` (also `/api/health`) | liveness — the process is up |
| GET | `/ready` | readiness — the database answers a query (503 otherwise) |
| GET | `/metrics` | Prometheus metrics |
| GET | `/api/tasks` | list tasks, newest first |
| GET | `/api/tasks/{id}` | one task (404 if missing) |
| POST | `/api/tasks` | create (validated: title 1–200 chars, priority LOW/MEDIUM/HIGH, status TODO/IN_PROGRESS/DONE) |
| PUT | `/api/tasks/{id}` | partial update |
| DELETE | `/api/tasks/{id}` | delete (204) |
| GET | `/api/tasks/stats` | counts per status for the KPI cards |

**Database.** One table, `tasks`, created by the Alembic migration `backend/alembic/versions/0001_create_tasks.py`.
The container runs `alembic upgrade head` before starting Uvicorn. Because every backend replica does this, the
migration takes a PostgreSQL **advisory lock** (`alembic/env.py`) so two pods starting together queue instead of racing
to create the same table.

**Metrics.** Default HTTP metrics (`http_requests_total`, `http_request_duration_seconds`) plus a business counter
`taskboard_task_events_total{event="created|updated|deleted"}`.

### Frontend (React)

Dashboard with sidebar, KPI cards (from `/api/tasks/stats`), filterable task table, status advance (PUT), delete (DELETE),
create-task modal (POST), activity feed, loading and backend-error states; responsive down to phone width.

## 5. Run locally

### Docker Compose (fastest)

```bash
docker compose up --build            # if 5432 is taken: POSTGRES_HOST_PORT=55432 docker compose up --build
```

| URL | |
|---|---|
| http://localhost:3000 | TaskBoard UI |
| http://localhost:8000/docs | Swagger |
| http://localhost:8000/health · /ready · /metrics | probes and metrics |

Start-up is health-gated: Postgres `pg_isready` → backend (migrations + `/health`) → frontend. Verify end to end with
`./scripts/smoke-test.sh http://localhost:3000`. Stop with `docker compose down` (add `-v` to wipe the database).

### Without Docker

```bash
cd backend && python3.12 -m venv .venv && source .venv/bin/activate && pip install -r requirements-dev.txt
export DATABASE_URL=postgresql+psycopg://taskboard:taskboard@localhost:5432/taskboard
alembic upgrade head && uvicorn app.main:app --reload --port 8000
cd ../frontend && npm ci && npm run dev    # http://localhost:5173, proxies /api to :8000
```

## 6. Testing

```bash
cd backend && pytest -v        # 16 passed
```

- `tests/conftest.py` sets `DATABASE_URL=sqlite://` **before** the app is imported and overrides the `get_db`
  dependency with an in-memory SQLite engine (`StaticPool`), so tests never touch PostgreSQL.
- Each test gets a fresh schema (create_all / drop_all), so test order doesn't matter.
- Coverage: health, readiness, root, create (+2 validation failures), list ordering, get (+404), update (+404),
  delete (+404), stats aggregation and the `/metrics` exposition — 7 endpoints in total.

## 7. Docker

| Image | Build | Runtime user | Notes |
|---|---|---|---|
| backend | 2 stages: deps into `/opt/venv`, then copy into a clean `python:3.12-slim` | `appuser` uid 10001 | `apt-get upgrade`; pip removed from the runtime image; `HEALTHCHECK` on `/health` |
| frontend | 2 stages: `node:22-alpine` → `npm ci && vite build`, then `nginxinc/nginx-unprivileged:1.29-alpine` | `nginx` uid 101 | `apk upgrade`; listens on 8080 (no root needed for the port); `BACKEND_URL` templated at start-up |

## 8. CI/CD — `.github/workflows/ci-cd.yml`

Triggers: push to `main`, pull requests to `main`, manual dispatch.

| Stage | Job | What happens | Fails the build when |
|---|---|---|---|
| 1 | **test** | `pytest -v` (JUnit report uploaded), `npm ci && npm run build` | any test fails / frontend doesn't compile |
| 2 | **image** (matrix: backend, frontend) | Buildx build tagged `ghcr.io/<owner>/taskboard-<component>:<github.sha>` → **Trivy** → push to **GHCR** (main only) | Trivy finds a fixable HIGH or CRITICAL CVE |
| 3 | **deploy-test** | creates a throw-away **kind** cluster, pulls the just-pushed images with a GHCR pull secret, `helm upgrade --install --wait`, runs `scripts/smoke-test.sh` (full CRUD) and checks `/metrics` | pods don't become Ready or any API call fails |
| 4 | **gitops** | rewrites the tags in `helm/taskboard/values-prod.yaml` to the commit SHA and pushes `chore(gitops): … [skip ci]` | — |

Pull requests run stages 1–2 without pushing, so a PR shows test and security results before merge.

**Verified:** every job green on the first run (see the repository's Actions tab); images are published as
[`ghcr.io/venkat1701/taskboard-backend`](https://github.com/venkat1701/devsecops-python/pkgs/container/taskboard-backend)
and `taskboard-frontend` with the commit SHA as the only tag (screenshots in `demo/screenshots/`).
Image tags are **always the commit SHA**, never `latest`, so `kubectl describe pod` → image tag → `git show <sha>`.

## 9. DevSecOps — Trivy

Each image is scanned in CI with `trivy image --severity HIGH,CRITICAL --ignore-unfixed --exit-code 1` (Trivy pinned to
0.75.0 and run from its official container image, not a floating action tag). The report is printed in the job log,
added to the run summary and uploaded as an artifact.

**What it scans:** OS packages (Debian 13 in the backend, Alpine 3.23 in the frontend) and language dependencies found
in the image (Python site-packages, including SBOMs embedded in wheels). **What the result means:** the current
images report **0 HIGH/CRITICAL fixable vulnerabilities** (`demo/evidence/trivy-local.txt`).

**A CVE we actually hit and fixed.** The first scan failed the gate with 4 HIGH findings in the backend's
*Python* layer — urllib3 (CVE-2026-97687, HTTPS-proxy traffic interception), msgpack (GHSA-6v7p-g79w-8964) and
setuptools (CVE-2025-47273, path traversal). None of these are app dependencies: they're libraries **vendored inside
pip** (`pip/_vendor/bom.cdx.json`). The API never runs pip in production, so the fix was to remove pip from the runtime
image (multi-stage build). The frontend failed with 44 HIGH Alpine findings (curl, openssl, c-ares, …) that already had
fixes; `apk upgrade` in the runtime stage cleared them. `--ignore-unfixed` keeps the gate actionable: it only fails on
problems that a rebuild or upgrade can actually solve.

## 10. Terraform (AWS)

See [`terraform/README.md`](terraform/README.md). Summary: VPC `10.20.0.0/16` across 2 AZs in `ap-south-1` with
**2 public + 2 private subnets**, a NAT gateway, and an **EKS 1.35** cluster with a managed node group (2× t3.medium,
AL2023) plus add-ons vpc-cni, coredns, kube-proxy, pod-identity-agent, metrics-server and aws-ebs-csi-driver.
`terraform plan` → **61 to add, 0 to change, 0 to destroy** (`demo/evidence/terraform-plan.txt`).
`terraform.tfvars.example` documents the inputs; credentials come from the AWS CLI chain and never touch Git.
Remember: `terraform destroy` when finished.

## 11. Kubernetes + Helm

Chart `helm/taskboard` renders:

| Resource | Notes |
|---|---|
| Deployment `…-backend` | 2–6 replicas via HPA; init container waits for Postgres; startup/readiness (`/ready`)/liveness (`/health`) probes; non-root, no privilege escalation, all capabilities dropped |
| Deployment `…-frontend` | 2 replicas; Nginx proxies to the backend Service via `BACKEND_URL` |
| Deployment `…-postgres` + PVC + Secret | `Recreate` strategy (RWO volume), `PGDATA` subdirectory (EBS volumes contain `lost+found`), PVC kept on uninstall |
| Services (ClusterIP) | backend `:8000`, frontend `:80`, postgres `:5432` |
| Ingress (Traefik) | `/api` → backend, `/` → frontend |
| HPA | CPU 60 % target, min 2 / max 6; the Deployment omits `replicas` while the HPA is on, so Helm/Argo don't fight it |
| ServiceMonitor | rendered only if the Prometheus Operator CRD exists (so the chart also installs on bare clusters such as CI's kind) |
| ConfigMap dashboard | Grafana dashboard JSON, auto-loaded by the Grafana sidecar |

Values files: `values.yaml` (defaults), `values-local.yaml` (k3d, local images), `values-dev.yaml` (1 replica, no HPA),
`values-prod.yaml` (EKS, GHCR images, updated by CI for Argo CD).

> Ingress controller choice: the community **ingress-nginx** project was retired in March 2026, so this project uses
> **Traefik** (built into k3s; one Helm install on EKS). Only `ingress.className` changes if you prefer another controller.

### Local cluster in one command (k3d)

```bash
./scripts/local-up.sh        # k3d cluster + kube-prometheus-stack + TaskBoard (writes .kube/taskboard.yaml)
export KUBECONFIG=$PWD/.kube/taskboard.yaml
kubectl get pods,svc,ingress,hpa -n taskboard
helm list -A
open http://taskboard.localhost:8080
./scripts/local-down.sh      # delete everything
```

### AWS EKS

```bash
cd terraform && terraform apply && $(terraform output -raw configure_kubectl) && cd ..
kubectl apply -f k8s/namespace.yaml -f k8s/storageclass-gp3.yaml

# ingress controller (creates an AWS load balancer in the public subnets)
helm repo add traefik https://traefik.github.io/charts
helm upgrade --install traefik traefik/traefik -n traefik --create-namespace

# monitoring
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm upgrade --install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  -n monitoring --create-namespace -f monitoring/prometheus-values.yaml

# application — either directly with Helm …
helm upgrade --install taskboard ./helm/taskboard -n taskboard -f helm/taskboard/values-prod.yaml
# … or the GitOps way with Argo CD (recommended; CI keeps values-prod.yaml current)
./argocd/install.sh

kubectl get svc -n traefik traefik   # EXTERNAL-IP = load balancer hostname → open it in the browser
```

The GHCR packages are linked to this public repository and inherit its **public** visibility, so clusters pull them
anonymously. If you fork into a private repo, create a pull secret and pass it to the chart:

```bash
kubectl -n taskboard create secret docker-registry ghcr-pull --docker-server=ghcr.io \
  --docker-username=<github-user> --docker-password=<PAT with read:packages>
# values: imagePullSecrets: [{name: ghcr-pull}]
```

### GitOps flow (Argo CD)

`git push` → CI tests, scans and pushes `:<sha>` images → CI commits the new tag to `values-prod.yaml` →
Argo CD notices the commit and syncs the cluster (automated sync with `prune` and `selfHeal`, so manual `kubectl edit`
drift is reverted). Rollback = `git revert` of the tag commit.

Try it locally: `./argocd/install.sh` installs Argo CD into the k3d cluster, and
`kubectl apply -n argocd -f argocd/application-local.yaml` registers an Application that tracks this GitHub repo
(values-prod.yaml + k3d overrides) into namespace `taskboard-gitops`. Verified: **Synced / Healthy** at the CI bot's
`chore(gitops)` commit, running the exact SHA-tagged GHCR images, and a manual `kubectl scale` was reverted by
self-heal within ~6 s (`demo/screenshots/argocd-app.png`).

## 12. Observability

| Component | How |
|---|---|
| `/metrics` | `prometheus-fastapi-instrumentator` + custom `taskboard_task_events_total` counter |
| Prometheus | kube-prometheus-stack (`monitoring/prometheus-values.yaml`); configured to pick up ServiceMonitors from every namespace |
| Scraping | the chart's ServiceMonitor targets the backend Service's `http` port every 15 s; the target shows as `serviceMonitor/taskboard/taskboard-taskboard-backend/0` → **UP** |
| Grafana | same stack; admin / `taskboard-admin` (demo only); sidecar loads the **TaskBoard — API Overview** dashboard from the chart's ConfigMap |

Dashboard panels: request rate, p95 latency, 5xx error ratio, backend targets UP, requests/sec by endpoint,
p50/p95/p99 latency, responses by status class, task events per minute, backend CPU per pod (the HPA signal).

```bash
kubectl -n monitoring port-forward svc/kube-prometheus-stack-prometheus 9090:9090   # http://localhost:9090/targets
kubectl -n monitoring port-forward svc/kube-prometheus-stack-grafana 3001:80        # http://localhost:3001
URL=http://taskboard.localhost:8080 ./scripts/load-test.sh                          # traffic for the panels; scaled the backend 2 → 4 pods (demo/evidence/hpa.txt)
```

## 13. Troubleshooting lab

```bash
kubectl apply -f troubleshooting/broken-image.yaml     # ImagePullBackOff → describe pod → wrong tag
kubectl apply -f troubleshooting/broken-service.yaml   # Service with no endpoints → label selector mismatch
kubectl get pods,endpoints -n taskboard --show-labels
kubectl delete -f troubleshooting/
```

## 14. Design decisions

- **Alembic owns the schema** (no `create_all` at app start-up); tests build their own schema.
- **Advisory-locked migrations** make "every replica migrates on start" safe.
- **Separate liveness and readiness**: a DB outage takes pods out of rotation (`/ready` → 503) without restarting them.
- **One image, many environments**: config comes from env vars (`DATABASE_URL`, `BACKEND_URL`), never baked in.
- **Pinned everything**: Python and npm dependencies, base image lines, Terraform providers (lock file), Trivy version.

## 15. Known issues and limitations

- PostgreSQL runs inside the cluster on a single-replica PVC — fine for a demo, but production should use Amazon RDS
  (backups, Multi-AZ, patching).
- Demo credentials (`taskboard/taskboard`, Grafana `taskboard-admin`) are in values files; use Sealed Secrets / External
  Secrets with AWS Secrets Manager for anything real. The app has no authentication.
- Terraform state is local; a team needs an S3 backend with locking.
- No TLS on the Ingress; add cert-manager + Let's Encrypt for a real hostname.
- The `gitops` job pushes to `main`; if branch protection is enabled, allow `github-actions[bot]` or switch to a PR.
- Single NAT gateway = one AZ dependency for outbound traffic (chosen for cost).
- HPA reacts within ~1–2 minutes (metrics-server scrape + stabilisation window); scale-down waits 5 minutes by default.
