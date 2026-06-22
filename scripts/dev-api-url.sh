#!/usr/bin/env bash
# 로컬 API base URL (기본 http://127.0.0.1:<port>)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
port="$(bash "$ROOT/scripts/read-dev-port.sh")"
host="${DEV_API_HOST:-127.0.0.1}"
echo "http://${host}:${port}"
