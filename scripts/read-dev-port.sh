#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PORT_FILE="$ROOT/.dev-local-port"

if [[ -n "${API_PORT:-}" ]]; then
  echo "$API_PORT"
  exit 0
fi

if [[ -n "${DEV_API_PORT:-}" ]]; then
  echo "$DEV_API_PORT"
  exit 0
fi

if [[ -f "$PORT_FILE" ]]; then
  port="$(tr -d '[:space:]' < "$PORT_FILE")"
  if [[ "$port" =~ ^[0-9]+$ ]]; then
    echo "$port"
    exit 0
  fi
fi

bash "$ROOT/scripts/pick-dev-port.sh"
