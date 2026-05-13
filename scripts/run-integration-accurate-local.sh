#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
npm run build
npx next start -p 3011 &
PID=$!
trap 'kill "$PID" 2>/dev/null || true' EXIT
for _ in $(seq 1 90); do
  curl -sf "http://127.0.0.1:3011/" >/dev/null && break
  sleep 1
done
INTEGRATION_BASE_URL="http://127.0.0.1:3011" npm run integration:accurate
