#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

# shellcheck disable=SC1091
source "$ROOT/scripts/ensure-node.sh"

port_in_use() {
  nc -z 127.0.0.1 "$1" 2>/dev/null
}

if [[ "${STUDY_DEV_KEEP_RUNNING:-0}" != "1" ]]; then
  bash "$ROOT/scripts/stop-study-dev-server.sh"
fi

PORT="${PORT:-$(bash "$ROOT/scripts/pick-dev-port.sh")}"

if port_in_use "$PORT"; then
  echo "[dev] Port ${PORT} already in use — picking another..." >&2
  PORT="$(bash "$ROOT/scripts/pick-dev-port.sh")"
fi

bash "$ROOT/scripts/write-dev-port.sh" "$PORT"

echo "[dev] API http://127.0.0.1:${PORT}  (LAN: ipconfig getifaddr en0)" >&2
echo "[dev] Port saved → .dev-local-port" >&2

exec npx next dev -H 0.0.0.0 -p "$PORT"
