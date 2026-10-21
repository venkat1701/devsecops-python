#!/usr/bin/env bash
# One-command local Kubernetes environment (k3d = k3s in Docker):
#   cluster + Traefik ingress + metrics-server (built into k3s) + kube-prometheus-stack + TaskBoard via Helm.
# Uses its own kubeconfig file so it never touches your other kubectl contexts.
set -euo pipefail
cd "$(dirname "$0")/.."

CLUSTER="${CLUSTER:-taskboard}"
HTTP_PORT="${HTTP_PORT:-8080}"
export KUBECONFIG="${KUBECONFIG_FILE:-$PWD/.kube/$CLUSTER.yaml}"
mkdir -p "$(dirname "$KUBECONFIG")"

if ! k3d cluster list "$CLUSTER" >/dev/null 2>&1; then
  k3d cluster create "$CLUSTER" --agents 1 -p "${HTTP_PORT}:80@loadbalancer" \
    --kubeconfig-update-default=false --kubeconfig-switch-context=false --wait
fi
k3d kubeconfig get "$CLUSTER" > "$KUBECONFIG"

echo ">> building images"
docker build -t taskboard-backend:local ./backend
docker build -t taskboard-frontend:local ./frontend
k3d image import -c "$CLUSTER" taskboard-backend:local taskboard-frontend:local

echo ">> monitoring (installed first so the ServiceMonitor CRD exists for the app chart)"
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts >/dev/null 2>&1 || true
helm repo update prometheus-community >/dev/null
helm upgrade --install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  -n monitoring --create-namespace -f monitoring/prometheus-values.yaml --wait --timeout 10m

echo ">> application"
kubectl apply -f k8s/namespace.yaml
helm upgrade --install taskboard ./helm/taskboard -n taskboard \
  -f helm/taskboard/values-local.yaml --wait --timeout 5m
# Images are re-imported under the same tag, so force new pods to pick them up.
kubectl -n taskboard rollout restart deploy/taskboard-taskboard-backend deploy/taskboard-taskboard-frontend
kubectl -n taskboard rollout status deploy/taskboard-taskboard-backend --timeout=180s
kubectl -n taskboard rollout status deploy/taskboard-taskboard-frontend --timeout=180s

kubectl get pods,svc,ingress,hpa -n taskboard
cat <<MSG

TaskBoard:   http://taskboard.localhost:${HTTP_PORT}/
API docs:    kubectl -n taskboard port-forward svc/taskboard-taskboard-backend 8000:8000  ->  http://localhost:8000/docs
Prometheus:  kubectl -n monitoring port-forward svc/kube-prometheus-stack-prometheus 9090:9090  ->  http://localhost:9090/targets
Grafana:     kubectl -n monitoring port-forward svc/kube-prometheus-stack-grafana 3001:80  ->  http://localhost:3001  (admin / taskboard-admin)

export KUBECONFIG=$KUBECONFIG
MSG
