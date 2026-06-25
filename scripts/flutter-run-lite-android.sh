#!/usr/bin/env bash
# 우열 라이트 — Android 에뮬레이터/기기 실행
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PORT_FILE="$ROOT/.dev-local-port"
API_BASE="${API_BASE_URL:-https://study-hazel-six.vercel.app}"

if [[ -f "$PORT_FILE" ]]; then
  PORT="$(tr -d '[:space:]' < "$PORT_FILE")"
  if [[ -n "$PORT" ]]; then
    API_BASE="http://10.0.2.2:${PORT}"
  fi
fi

cd "$ROOT/flutter_app"

FLUTTER_DEFINE_ARGS=(
  --flavor lite
  --dart-define=APP_VARIANT=lite
  --dart-define=API_BASE_URL="$API_BASE"
)
# shellcheck source=flutter-oauth-defines.sh
source "$ROOT/scripts/flutter-oauth-defines.sh"
flutter_oauth_append_defines FLUTTER_DEFINE_ARGS

exec flutter run "${FLUTTER_DEFINE_ARGS[@]}" "$@"
