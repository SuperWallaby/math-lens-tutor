#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PORT_FILE="$ROOT/.dev-local-port"

if [[ -n "${API_PORT:-}" ]]; then
  echo "$API_PORT"
  exit 0
fi

if [[ -f "$PORT_FILE" ]]; then
  port="$(tr -d '[:space:]' < "$PORT_FILE")"
  if [[ "$port" =~ ^[0-9]+$ ]] && bash "$ROOT/scripts/is-study-api-up.sh" "$port"; then
    echo "$port"
    exit 0
  fi
fi

if existing="$(bash "$ROOT/scripts/find-study-api-port.sh" 2>/dev/null)"; then
  echo "$existing"
  exit 0
fi

bash "$ROOT/scripts/pick-dev-port.sh"
