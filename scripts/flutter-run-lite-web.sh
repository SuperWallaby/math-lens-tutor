#!/usr/bin/env bash
# 우열 라이트 — Chrome / web-server (로컬 API 권장)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
API_BASE="${FLUTTER_API_BASE_URL:-$(bash "$ROOT/scripts/dev-api-url.sh")}"
FLUTTER_DEFINE_ARGS=(
  --dart-define=APP_VARIANT=lite
  --dart-define=API_BASE_URL="$API_BASE"
)

load_env_var() {
  local key="$1"
  local file="$ROOT/.env.local"
  [[ -f "$file" ]] || return 0
  local line
  line="$(grep -E "^${key}=" "$file" | tail -1 || true)"
  [[ -n "$line" ]] || return 0
  printf '%s' "${line#*=}"
}

web_id="$(load_env_var GOOGLE_CLIENT_ID_WEB)"
[[ -n "$web_id" ]] && FLUTTER_DEFINE_ARGS+=(--dart-define=GOOGLE_CLIENT_ID_WEB="$web_id")

if ! nc -z 127.0.0.1 "$(bash "$ROOT/scripts/read-dev-port.sh")" 2>/dev/null; then
  echo "[lite-web] 로컬 API가 없습니다. 먼저 실행: npm run dev:next  (또는 yarn app)" >&2
  echo "[lite-web] 프로덕션 API는 CORS 배포 전까지 브라우저에서 막힐 수 있습니다." >&2
fi

cd "$ROOT/flutter_app"
DEVICE="${FLUTTER_DEVICE:-web-server}"
PORT="${FLUTTER_WEB_PORT:-5199}"

exec flutter run -d "$DEVICE" \
  --web-port="$PORT" \
  "${FLUTTER_DEFINE_ARGS[@]}" \
  "$@"
