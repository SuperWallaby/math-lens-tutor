#!/usr/bin/env bash
# Flutter 실기기(iPhone)용 API base URL — Bonjour .local 우선.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
port="${1:?port required}"

bonjour="$(scutil --get LocalHostName 2>/dev/null | tr '[:upper:]' '[:lower:]' || true)"

# iPhone 실기기: .local 이 USB 192.0.0.x / Wi‑Fi IP 모두에서 가장 안정적
if [[ -n "$bonjour" ]]; then
  echo "http://${bonjour}.local:${port}"
  exit 0
fi

ip="$(bash "$ROOT/scripts/get-lan-ip.sh")"
if [[ "$ip" != "127.0.0.1" ]]; then
  echo "http://${ip}:${port}"
  exit 0
fi

echo "http://127.0.0.1:${port}"
