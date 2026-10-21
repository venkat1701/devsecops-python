#!/usr/bin/env bash
# End-to-end API check through whatever URL fronts the app (compose :3000, ingress, or port-forward).
set -euo pipefail
URL="${1:-${URL:-http://localhost:3000}}"
fail() { echo "FAIL: $*" >&2; exit 1; }

curl -fsS "$URL/" | grep -q '<div id="root">' || fail "frontend not served"
[ "$(curl -fsS "$URL/api/health")" = '{"status":"UP"}' ] || fail "/api/health"
id=$(curl -fsS -X POST "$URL/api/tasks" -H 'Content-Type: application/json' \
      -d '{"title":"smoke test","priority":"LOW"}' | python3 -c 'import sys,json;print(json.load(sys.stdin)["id"])')
curl -fsS "$URL/api/tasks/$id" >/dev/null || fail "GET task"
curl -fsS -X PUT "$URL/api/tasks/$id" -H 'Content-Type: application/json' -d '{"status":"DONE"}' | grep -q '"DONE"' || fail "PUT task"
curl -fsS "$URL/api/tasks/stats" | grep -q '"total"' || fail "stats"
[ "$(curl -s -o /dev/null -w '%{http_code}' -X DELETE "$URL/api/tasks/$id")" = 204 ] || fail "DELETE task"
[ "$(curl -s -o /dev/null -w '%{http_code}' "$URL/api/tasks/$id")" = 404 ] || fail "task still exists"
echo "Smoke test passed against $URL"
