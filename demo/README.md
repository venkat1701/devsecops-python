# Demo assets

| File | What |
|---|---|
| `TaskBoard-DevSecOps-Capstone.pptx` / `.pdf` | presentation deck (17 slides, speaker notes on every slide) |
| `VIDEO-SCRIPT.md` | step-by-step recording script with narration |
| `presentation.mp4` | **demo video — record and add before submitting (mandatory, see script below)** |
| `screenshots/` | app via Ingress, mobile view, create modal, Swagger, Prometheus targets (UP), Grafana dashboard, green GitHub Actions run, GHCR package with SHA tag, Argo CD Synced/Healthy |
| `evidence/pytest.txt` | `pytest -v` → 16 passed |
| `evidence/trivy-local.txt` | Trivy HIGH/CRITICAL scan of both images → 0 findings, exit 0 |
| `evidence/terraform-plan.txt` | `terraform plan` → 61 to add, 0 to change, 0 to destroy |
| `evidence/kubernetes.txt` | `kubectl get pods/svc/ingress/hpa`, `helm list` |
| `evidence/hpa.txt` | HPA scaling 2 → 3 → 4 pods under load |
| `evidence/metrics.txt` | raw `/metrics` output |
| `evidence/docker-compose.txt` | `docker compose ps` with all three services healthy |

## Video script

The full recording script — prep, exact commands, narration and the teardown — is in
[`VIDEO-SCRIPT.md`](VIDEO-SCRIPT.md).
