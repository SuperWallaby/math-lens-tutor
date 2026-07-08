#!/usr/bin/env bash
# Gracefully stop processes listening on a TCP port.
set -euo pipefail

port="${1:?port required}"
[[ "$port" =~ ^[0-9]+$ ]] || exit 0

kill_pid_gracefully() {
  local pid="$1"
  [[ "$pid" =~ ^[0-9]+$ ]] || return 0

  if ! kill -0 "$pid" 2>/dev/null; then
    return 0
  fi

  echo "[dev] Stopping pid ${pid} on port ${port}..." >&2
  kill "$pid" 2>/dev/null || true

  local i
  for ((i = 1; i <= 20; i++)); do
    if ! kill -0 "$pid" 2>/dev/null; then
      return 0
    fi
    sleep 0.25
  done

  echo "[dev] Force killing pid ${pid}..." >&2
  kill -9 "$pid" 2>/dev/null || true
}

pid=""
while IFS= read -r pid; do
  [[ -n "$pid" ]] && kill_pid_gracefully "$pid"
done < <(lsof -tiTCP:"$port" -sTCP:LISTEN 2>/dev/null || true)
