#!/usr/bin/env bash
# Fixed Flutter web dev port (OAuth redirect URI must stay stable).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PORT="${FLUTTER_WEB_PORT:-8080}"

if nc -z 127.0.0.1 "$PORT" 2>/dev/null; then
  echo "[flutter] Web port ${PORT} in use — stopping existing listener..." >&2
  bash "$ROOT/scripts/stop-listeners-on-port.sh" "$PORT"
  sleep 0.5
fi

echo "$PORT"
