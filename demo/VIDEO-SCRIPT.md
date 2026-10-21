# Demo video script (≈15 minutes)

Record with QuickTime (File → New Screen Recording) or OBS at 1080p. Save as `demo/presentation.mp4`
(keep it under 100 MB: QuickTime → File → Export As → 1080p usually lands at 40–80 MB for 15 min; if bigger, attach it to
a GitHub Release instead and link it in the README).

Lines in *italics* are what you say. Code blocks are what you run. Increase your terminal font to ~18 pt first.

---

## 0. Before you hit record (≈25 min of prep, not recorded)

```bash
cd ~/Desktop/capstone/devsecops-python
git pull

# AWS: create the infrastructure ahead of time (apply takes ~15 min)
cd terraform && terraform init && terraform apply && cd ..
./scripts/eks-up.sh              # Traefik + Prometheus/Grafana + Argo CD + TaskBoard on EKS, prints the app URL

export KUBECONFIG=$PWD/.kube/eks.yaml
LB=$(kubectl -n traefik get svc traefik -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'); echo $LB
```

Open these browser tabs in order:

1. The deck: `demo/TaskBoard-DevSecOps-Capstone.pptx` (Keynote/PowerPoint, presenter view)
2. https://github.com/venkat1701/devsecops-python
3. https://github.com/venkat1701/devsecops-python/actions
4. AWS Console → **VPC** → Your VPCs (region **Mumbai ap-south-1**)
5. AWS Console → **EKS** → Clusters → `taskboard-eks`
6. `http://<LB>/` (the app on EKS)

Start these port-forwards in a second terminal and leave them running:

```bash
export KUBECONFIG=$PWD/.kube/eks.yaml
kubectl -n argocd port-forward svc/argocd-server 8443:443 &
kubectl -n monitoring port-forward svc/kube-prometheus-stack-prometheus 9090:9090 &
kubectl -n monitoring port-forward svc/kube-prometheus-stack-grafana 3001:80 &
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d; echo
```

Tabs 7–9: https://localhost:8443 (Argo CD, log in as `admin`), http://localhost:9090/targets,
http://localhost:3001 (Grafana, `admin` / `taskboard-admin`, open **TaskBoard — API Overview**).

---

## 1. Slides (4–5 min)

Present the deck. The speaker notes on each slide are the script; keep each slide to about 20 seconds and spend
longer on **Architecture**, **CI/CD**, **DevSecOps** and **Making it work**.

*"That's the design. Now let me show every piece of it running for real."*

## 2. CI/CD: trigger a push (2 min)

Make a visible change so the pipeline has something to ship, e.g. the dashboard subtitle:

```bash
sed -i '' "s/Here’s what’s happening with your team today./Here’s what’s happening with your team today — shipped by CI./" frontend/src/main.jsx
git commit -am "feat(ui): mention CI in the dashboard subtitle"
git pull --rebase && git push      # pull first: CI's GitOps job commits to main too
```

Switch to the **Actions** tab and open the new run.

*"Every push to main starts this pipeline. Stage one runs 16 pytest tests and builds the React app — a failing test
stops everything here. Stage two builds each image once, and Trivy scans it: any fixable HIGH or CRITICAL CVE fails the
job, so a vulnerable image never reaches the registry."*

Click **Image backend** → the Trivy step → show the `0` table.

*"Only then is it pushed to GitHub Container Registry, tagged with the commit SHA — never `latest`."*

Open the repo's **Packages** → `taskboard-backend` and point at the SHA tag.

*"Stage three proves the Helm chart actually deploys: a throwaway kind cluster pulls these exact images and a smoke test
does create, read, update and delete through the frontend. Stage four writes the new SHA into values-prod.yaml — that
commit is what Argo CD deploys."*

Leave it running (~4 min) and move on; come back to it in section 5.

## 3. Codebase tour (1–1.5 min)

In your editor, open the files as you name them:

- `backend/app/main.py` — *"FastAPI: the CRUD endpoints, liveness `/health`, readiness `/ready` which checks the
  database, and `/metrics` for Prometheus."*
- `backend/alembic/env.py` — *"Every pod runs migrations on start, so I take a Postgres advisory lock to stop two pods
  racing."*
- `backend/tests/conftest.py` — *"Tests run on an in-memory SQLite database, never the real one."*
- `backend/Dockerfile` and `frontend/Dockerfile` — *"Multi-stage builds, non-root users, pip removed from the runtime
  image — that's what fixed the Trivy findings."*
- `helm/taskboard/` — *"One chart for local, dev and production; values files change only what differs."*
- `.github/workflows/ci-cd.yml` — *"The four stages you just saw."*

## 4. Terraform + AWS (2 min)

```bash
cd terraform
terraform plan          # should report "No changes" — the real infrastructure matches the code
terraform output
cd ..
```

*"Terraform created all of this in ap-south-1: a VPC with two public and two private subnets, a NAT gateway, and an
EKS 1.35 cluster with two worker nodes, plus the add-ons the app needs — the EBS CSI driver for the database volume and
metrics-server for autoscaling. The plan now shows no changes: the cloud matches the code."*

Optionally scroll `demo/evidence/terraform-apply.txt` to show the original `Apply complete!` line.

AWS Console: **VPC** tab → select `taskboard-eks-vpc` → **Subnets** (show the 2 public + 2 private) →
**EKS** tab → `taskboard-eks` (Active, 1.35) → **Compute** (node group, 2 nodes).

## 5. Argo CD: GitOps (1.5 min)

Back to the Actions tab — the run should be green now. Then the Argo CD tab → application `taskboard`.

*"CI never touches the cluster. It commits the new image tag to Git, and Argo CD, running inside the cluster, notices
the commit and syncs. Here it is: Synced and Healthy, at the commit the pipeline just wrote."*

Click **History and Rollback** to show the revisions. Then demonstrate self-heal:

```bash
kubectl -n taskboard scale deploy/taskboard-taskboard-frontend --replicas=1
kubectl -n taskboard get deploy taskboard-taskboard-frontend -w     # watch it go back to 2, then Ctrl-C
```

*"If someone changes the cluster by hand, Argo CD puts it back to what Git says. Rolling back is just a git revert."*

Refresh the app tab — the new subtitle from section 2 is live.

## 6. Kubernetes (1 min)

```bash
kubectl get nodes
kubectl get pods,svc,ingress,hpa -n taskboard
helm list -A
```

*"Two backend and two frontend replicas, all Running, ClusterIP services, and an Ingress that sends `/api` to FastAPI
and everything else to the React app, behind an AWS Network Load Balancer. The HPA keeps between 2 and 6 backend
pods."*

Click around the app on the load balancer URL: create a task, advance its status, delete it.

## 7. Prometheus (30 s)

Prometheus tab → **Status → Target health** → search `taskboard`.

*"Prometheus found every backend pod through the ServiceMonitor in the Helm chart. All targets are UP."*

## 8. Grafana + autoscaling (1.5 min)

```bash
URL=http://$LB REQUESTS=2000 CONCURRENCY=20 ./scripts/load-test.sh &
kubectl get hpa -n taskboard -w
```

Switch to Grafana while it runs.

*"This dashboard ships inside the Helm chart. Request rate, p95 latency, error ratio and per-endpoint traffic are moving
live. The 4xx line is the load test deliberately asking for missing tasks. And as CPU crosses 60 %, the autoscaler adds
backend pods — Prometheus picks them up as new targets automatically."*

Back to the terminal to show `REPLICAS` going up.

## 9. Close (20 s)

*"So: one commit, tested, scanned, published, deployed by GitOps onto infrastructure defined in code, and observed
live. Thanks for watching."*

---

## After recording — do not skip (stops AWS billing)

```bash
./scripts/eks-down.sh        # deletes the load balancer and EBS volume, then runs terraform destroy (~10 min)
```

Screenshot the final `Destroy complete!` line for the submission, then confirm in the AWS Console (ap-south-1) that
the `taskboard-eks` cluster and `taskboard-eks-vpc` are gone.

Commit the video:

```bash
cp ~/Movies/<your recording>.mp4 demo/presentation.mp4
git add demo/presentation.mp4 && git commit -m "docs(demo): add presentation video" && git push
```
