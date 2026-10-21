#!/usr/bin/env bash
# Removes the AWS resources Kubernetes created (load balancer, EBS volumes) and then the Terraform stack.
# Without the first part `terraform destroy` stalls on VPC/subnet dependencies.
set -euo pipefail
cd "$(dirname "$0")/.."
export KUBECONFIG="${KUBECONFIG_FILE:-$PWD/.kube/eks.yaml}"

if kubectl cluster-info >/dev/null 2>&1; then
  echo ">> removing workloads that own AWS resources"
  kubectl -n argocd delete application taskboard --wait=true --timeout=5m --ignore-not-found || true
  kubectl delete namespace taskboard --wait=true --timeout=5m --ignore-not-found || true   # PVC -> EBS volume
  helm uninstall traefik -n traefik --wait || true                                         # NLB
  helm uninstall kube-prometheus-stack -n monitoring --wait || true
  helm uninstall argocd -n argocd --wait || true
  echo ">> waiting for EBS-backed PVs to be released"
  for _ in $(seq 1 30); do [ "$(kubectl get pv --no-headers 2>/dev/null | wc -l)" -eq 0 ] && break; sleep 10; done
fi

terraform -chdir=terraform destroy -auto-approve
rm -f "$KUBECONFIG"
