#!/usr/bin/env bash
# Installs Argo CD into the current cluster and registers the TaskBoard Application.
set -euo pipefail
cd "$(dirname "$0")/.."
helm repo add argo https://argoproj.github.io/argo-helm >/dev/null 2>&1 || true
helm repo update argo >/dev/null
helm upgrade --install argocd argo/argo-cd -n argocd --create-namespace \
  --set dex.enabled=false --set notifications.enabled=false --wait --timeout 10m
kubectl apply -n argocd -f argocd/application.yaml
echo "UI:       kubectl -n argocd port-forward svc/argocd-server 8443:443  ->  https://localhost:8443"
echo "Password: kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
