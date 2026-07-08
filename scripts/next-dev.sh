#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

# shellcheck disable=SC1091
source "$ROOT/scripts/ensure-node.sh"

if [[ "${STUDY_DEV_KEEP_RUNNING:-0}" != "1" ]]; then
  bash "$ROOT/scripts/stop-study-dev-server.sh"
fi

PORT="$(bash "$ROOT/scripts/ensure-dev-port-free.sh" "${PORT:-}")"

bash "$ROOT/scripts/write-dev-port.sh" "$PORT"

LAN_IP="$(bash "$ROOT/scripts/get-lan-ip.sh")"
echo "[dev] API http://127.0.0.1:${PORT}  (LAN: http://${LAN_IP}:${PORT})" >&2
echo "[dev] Port saved → .dev-local-port" >&2

exec npx next dev -H 0.0.0.0 -p "$PORT"
