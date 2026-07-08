#!/usr/bin/env bash
# 로컬 dev API 포트를 stdout 으로 출력 (고정 기본값, 랜덤 없음).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=dev-port-default.sh
source "$ROOT/scripts/dev-port-default.sh"

if [[ -n "${API_PORT:-}" ]]; then
  echo "$API_PORT"
  exit 0
fi

if [[ -n "${DEV_API_PORT:-}" ]]; then
  echo "$DEV_API_PORT"
  exit 0
fi

echo "$STUDY_DEV_DEFAULT_PORT"
