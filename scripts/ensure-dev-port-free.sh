#!/usr/bin/env bash
# Resolve dev API port and force-free listeners on it.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

port_in_use() {
  nc -z 127.0.0.1 "$1" 2>/dev/null
}

PORT="${1:-$(bash "$ROOT/scripts/pick-dev-port.sh")}"
[[ "$PORT" =~ ^[0-9]+$ ]] || {
  echo "[dev] Invalid port: ${PORT}" >&2
  exit 1
}

if port_in_use "$PORT"; then
  echo "[dev] Port ${PORT} in use — stopping listeners..." >&2
  bash "$ROOT/scripts/stop-listeners-on-port.sh" "$PORT"
  sleep 0.5
fi

if port_in_use "$PORT"; then
  echo "[dev] Port ${PORT} still in use after stop." >&2
  exit 1
fi

echo "$PORT"
