#!/usr/bin/env bash
# 이 프로젝트의 Next.js dev 서버(.next/dev/lock) 종료
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LOCK_FILE="$ROOT/.next/dev/lock"

kill_pid_gracefully() {
  local pid="$1"
  [[ "$pid" =~ ^[0-9]+$ ]] || return 0

  if ! kill -0 "$pid" 2>/dev/null; then
    return 0
  fi

  echo "[dev] Stopping Next.js dev (pid ${pid})..." >&2
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

read_lock_pid() {
  [[ -f "$LOCK_FILE" ]] || return 0
  node -e "
    try {
      const j = JSON.parse(require('fs').readFileSync(process.argv[1], 'utf8'));
      if (j.pid) process.stdout.write(String(j.pid));
    } catch {}
  " "$LOCK_FILE" 2>/dev/null || true
}

read_lock_port() {
  [[ -f "$LOCK_FILE" ]] || return 0
  node -e "
    try {
      const j = JSON.parse(require('fs').readFileSync(process.argv[1], 'utf8'));
      if (j.port) process.stdout.write(String(j.port));
    } catch {}
  " "$LOCK_FILE" 2>/dev/null || true
}

stop_listeners_on_port() {
  local port="$1"
  [[ "$port" =~ ^[0-9]+$ ]] || return 0

  local pid
  while IFS= read -r pid; do
    [[ -n "$pid" ]] && kill_pid_gracefully "$pid"
  done < <(lsof -tiTCP:"$port" -sTCP:LISTEN 2>/dev/null || true)
}

main() {
  local lock_pid lock_port
  lock_pid="$(read_lock_pid)"
  lock_port="$(read_lock_port)"

  if [[ -n "$lock_pid" ]]; then
    kill_pid_gracefully "$lock_pid"
  fi

  if [[ -n "$lock_port" ]]; then
    stop_listeners_on_port "$lock_port"
  fi

  if [[ -f "$ROOT/.dev-local-port" ]]; then
    local saved_port
    saved_port="$(tr -d '[:space:]' < "$ROOT/.dev-local-port" 2>/dev/null || true)"
    if [[ "$saved_port" =~ ^[0-9]+$ ]]; then
      stop_listeners_on_port "$saved_port"
    fi
  fi

  rm -f "$LOCK_FILE"
}

main "$@"
