#!/usr/bin/env bash
# Generates API traffic so Grafana panels (and, with enough load, the HPA) have something to show.
#   URL=http://taskboard.localhost:8080 ./scripts/load-test.sh
set -euo pipefail
URL="${URL:-http://taskboard.localhost:8080}"
REQUESTS="${REQUESTS:-500}"
CONCURRENCY="${CONCURRENCY:-10}"

hit() {
  curl -s -o /dev/null "$URL/api/tasks"
  curl -s -o /dev/null "$URL/api/tasks/stats"
  curl -s -o /dev/null "$URL/api/health"
  curl -s -o /dev/null "$URL/api/tasks/999999"   # deliberate 404s for the status-class panel
}
export -f hit; export URL
seq 1 "$REQUESTS" | xargs -P "$CONCURRENCY" -I{} bash -c hit
echo "Load test completed: $((REQUESTS * 4)) requests against $URL"
