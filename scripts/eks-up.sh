#!/usr/bin/env bash
# After `terraform apply`: wire the EKS cluster up the same way as the local one —
# Traefik ingress (AWS NLB), kube-prometheus-stack, Argo CD, then TaskBoard via GitOps.
# Uses its own kubeconfig file so it never touches your other kubectl contexts.
set -euo pipefail
cd "$(dirname "$0")/.."

REGION="$(terraform -chdir=terraform output -raw region)"
CLUSTER="$(terraform -chdir=terraform output -raw cluster_name)"
export KUBECONFIG="${KUBECONFIG_FILE:-$PWD/.kube/eks.yaml}"
mkdir -p "$(dirname "$KUBECONFIG")"
aws eks update-kubeconfig --region "$REGION" --name "$CLUSTER" --kubeconfig "$KUBECONFIG" >/dev/null
kubectl get nodes -o wide

echo ">> bootstrap: namespace + default gp3 StorageClass"
kubectl apply -f k8s/namespace.yaml -f k8s/storageclass-gp3.yaml

echo ">> ingress controller (internet-facing NLB in the public subnets)"
helm repo add traefik https://traefik.github.io/charts >/dev/null 2>&1 || true
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts >/dev/null 2>&1 || true
helm repo update traefik prometheus-community >/dev/null
helm upgrade --install traefik traefik/traefik -n traefik --create-namespace \
  --set 'service.annotations.service\.beta\.kubernetes\.io/aws-load-balancer-type=nlb' \
  --set 'service.annotations.service\.beta\.kubernetes\.io/aws-load-balancer-scheme=internet-facing' \
  --wait --timeout 10m

echo ">> monitoring"
helm upgrade --install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  -n monitoring --create-namespace -f monitoring/prometheus-values.yaml --wait --timeout 15m

echo ">> Argo CD + TaskBoard Application (tracks helm/taskboard/values-prod.yaml on main)"
./argocd/install.sh
for _ in $(seq 1 60); do
  s="$(kubectl -n argocd get application taskboard -o jsonpath='{.status.sync.status}/{.status.health.status}' 2>/dev/null || true)"
  echo "   argo: ${s:-pending}"; [ "$s" = "Synced/Healthy" ] && break; sleep 10
done

LB="$(kubectl -n traefik get svc traefik -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')"
echo ">> waiting for load balancer DNS: $LB"
for _ in $(seq 1 60); do curl -sf -o /dev/null "http://$LB/api/health" && break; sleep 10; done
./scripts/smoke-test.sh "http://$LB"

kubectl get pods,svc,ingress,hpa -n taskboard
cat <<MSG

TaskBoard on EKS:  http://$LB/
export KUBECONFIG=$KUBECONFIG
Tear down when finished:  ./scripts/eks-down.sh
MSG
