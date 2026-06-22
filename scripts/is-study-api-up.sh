#!/usr/bin/env bash
# Study API(우열)가 해당 포트에서 응답하는지 확인 (다른 Next 앱 404 제외).
set -euo pipefail

port="${1:?port required}"
code="$(curl -sf -o /dev/null -w "%{http_code}" "http://127.0.0.1:${port}/api/learning/profile" 2>/dev/null || echo 000)"

case "$code" in
  200 | 401) exit 0 ;;
  *) exit 1 ;;
esac
