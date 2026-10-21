# Demo assets

| File | What |
|---|---|
| `TaskBoard-DevSecOps-Capstone.pptx` / `.pdf` | presentation deck (17 slides, speaker notes on every slide) |
| `presentation.mp4` | **demo video — record and add before submitting (mandatory, see script below)** |
| `screenshots/` | app via Ingress, mobile view, create modal, Swagger, Prometheus targets (UP), Grafana dashboard, green GitHub Actions run, GHCR package with SHA tag, Argo CD Synced/Healthy |
| `evidence/pytest.txt` | `pytest -v` → 16 passed |
| `evidence/trivy-local.txt` | Trivy HIGH/CRITICAL scan of both images → 0 findings, exit 0 |
| `evidence/terraform-plan.txt` | `terraform plan` → 61 to add, 0 to change, 0 to destroy |
| `evidence/kubernetes.txt` | `kubectl get pods/svc/ingress/hpa`, `helm list` |
| `evidence/hpa.txt` | HPA scaling 2 → 3 → 4 pods under load |
| `evidence/metrics.txt` | raw `/metrics` output |
| `evidence/docker-compose.txt` | `docker compose ps` with all three services healthy |

## Video script (~12–15 min)

Record with QuickTime (File → New Screen Recording) or OBS and save as `demo/presentation.mp4`
(keep it under 100 MB for a normal git push, or attach it to a GitHub Release).

1. **Slides (4–5 min)** — present the deck; the speaker notes are the script.
2. **Codebase (1 min)** — repo tree, `backend/app/main.py`, `tests/conftest.py`, both Dockerfiles, the Helm chart.
3. **CI/CD (2 min)** — make a small change to a code file (e.g. a UI string; README/demo-only pushes skip CI), `git commit -m "feat(ui): …" && git push`, open the
   Actions run and show test → image (open a Trivy log) → deploy-test → gitops all green; open GHCR packages and show
   the SHA tags.
4. **Terraform (2 min)** — `terraform plan` (or show `demo/evidence/terraform-plan.txt`); if applied, the AWS console
   VPC (2 public subnets) and EKS cluster in ap-south-1; then `terraform destroy`.
5. **Argo CD (1 min)** — `kubectl -n argocd port-forward svc/argocd-server 8443:443` (password:
   `kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d`), show
   `taskboard-gitops` Synced + Healthy at the CI `chore(gitops)` commit; `kubectl -n taskboard-gitops scale
   deploy/taskboard-taskboard-frontend --replicas=1` and watch self-heal put it back to 2.
6. **Kubernetes (1 min)** — `kubectl get pods,svc,ingress,hpa -n taskboard`, `helm list -A`, open the app via the Ingress.
7. **Prometheus (30 s)** — `/targets`, filter `taskboard`, all UP.
8. **Grafana (1 min)** — run `scripts/load-test.sh`, show the TaskBoard dashboard updating, then `kubectl get hpa -w`.
