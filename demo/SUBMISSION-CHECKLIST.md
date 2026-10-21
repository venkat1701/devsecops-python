# Submission checklist → evidence

Every item from [GRADING.md](../GRADING.md), mapped to where it is satisfied in this repository.
Repository: https://github.com/venkat1701/devsecops-python

| Module | Requirement | Evidence |
|---|---|---|
| M1 | FastAPI `/health`, ≥ 4 REST endpoints, Alembic migration, frontend calling the API | `backend/app/`, `backend/alembic/versions/0001_create_tasks.py`, `frontend/src/main.jsx`, `screenshots/app-docker-compose-localhost-3000.png`, `screenshots/swagger.png` |
| M1 | Responsive UI | `screenshots/app-mobile.png` |
| M2 | `pytest` passes, ≥ 5 tests on ≥ 3 endpoints, test DB, `pytest.ini`/`conftest.py` | `backend/tests/` (16 tests), `backend/pytest.ini`, `backend/tests/conftest.py`, `screenshots/pytest.png`, `evidence/pytest.txt` |
| M3 | Public repo, meaningful commits (≥ 10), `.gitignore` | `screenshots/github-commit-history.png`, `.gitignore` |
| M4 | Backend Dockerfile builds, frontend multi-stage, non-root, `docker compose up --build` | `backend/Dockerfile`, `frontend/Dockerfile`, `docker-compose.yml`, `screenshots/docker-compose-up.png` (includes `id` → uid 10001 / 101), `screenshots/app-docker-compose-localhost-3000.png` |
| M5 | Workflow on push to main, pytest gate, frontend build, both images built, pushed to GHCR, SHA tags | `.github/workflows/ci-cd.yml`, `screenshots/github-actions-run.png`, `screenshots/ghcr-package.png` |
| M6 | Trivy on both images, fails on HIGH/CRITICAL, explanation | workflow job `image`, `screenshots/trivy-ci.png`, `evidence/trivy-local.txt`, README §9 (CVE explanation) |
| M7 | Valid HCL, init, non-empty plan, VPC + 2 public subnets, EKS + node group, destroy, tfvars example | `terraform/`, `terraform/terraform.tfvars.example`, `screenshots/terraform-plan.png`, `screenshots/terraform-apply.png`, `screenshots/aws-vpc-eks.png`, `evidence/terraform-plan.txt`, `evidence/terraform-apply.txt` — **destroy: `evidence/terraform-destroy.txt` after the video is recorded** |
| M7 | AWS Console screenshot of VPC + EKS | `screenshots/aws-vpc-eks.png` (AWS CLI); **take one AWS Console screenshot of each while recording the video** |
| M8 | `k8s/namespace.yaml`, Helm chart, `helm upgrade --install`, ≥ 2 replicas each, ClusterIP services, Ingress `/` + `/api`, pods Running | `k8s/`, `helm/taskboard/`, `screenshots/eks-kubectl.png`, `screenshots/eks-helm-argocd.png`, `screenshots/eks-app-load-balancer.png`, `evidence/eks-kubernetes.txt` |
| M9 | `/metrics`, Prometheus scraping (UP), Grafana with live panel | `monitoring/prometheus-values.yaml`, `screenshots/metrics-curl.png`, `screenshots/eks-prometheus-targets.png`, `screenshots/eks-grafana-dashboard.png` |
| M10 | README, PPT in repo, **video in `demo/`** | `README.md`, `demo/TaskBoard-DevSecOps-Capstone.pptx` / `.pdf`, **`demo/presentation.mp4` — record with `VIDEO-SCRIPT.md`** |
| Video | ArgoCD synced + GitOps flow | `argocd/`, `screenshots/eks-argocd-app.png`, `screenshots/argocd-app.png` |
| Security | No secrets committed | AWS credentials come from the CLI chain; `*.tfvars`, state and kubeconfigs are git-ignored |

## Still to do (only the student can)

1. Record `demo/presentation.mp4` following [`VIDEO-SCRIPT.md`](VIDEO-SCRIPT.md) while the EKS stack is still running.
2. During the recording, open the AWS Console (ap-south-1) VPC and EKS pages; save one screenshot of each to `demo/screenshots/`.
3. `./scripts/eks-down.sh 2>&1 | tee demo/evidence/terraform-destroy.txt` and screenshot the `Destroy complete!` line.
4. Commit and push, then submit the repository URL in the form linked from [SUBMISSION.md](../SUBMISSION.md).
