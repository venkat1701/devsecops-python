#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
k3d cluster delete "${CLUSTER:-taskboard}"
rm -f ".kube/${CLUSTER:-taskboard}.yaml"
