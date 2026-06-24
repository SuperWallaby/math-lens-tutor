#!/usr/bin/env bash
# Chrome Flutter + read-dev-port 기반 API URL + optional auto hot reload
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
API_BASE="${FLUTTER_API_BASE_URL:-$(bash "$ROOT/scripts/dev-api-url.sh")}"
FLUTTER_PID_FILE="$ROOT/.flutter-run.pid"
WATCH_PID=""
FLUTTER_DEFINE_ARGS=(--dart-define="API_BASE_URL=$API_BASE")

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
ios_id="$(load_env_var GOOGLE_CLIENT_ID_IOS)"
android_id="$(load_env_var GOOGLE_CLIENT_ID_ANDROID)"
kakao_key="$(load_env_var KAKAO_NATIVE_APP_KEY)"
[[ -n "$web_id" ]] && FLUTTER_DEFINE_ARGS+=(--dart-define=GOOGLE_CLIENT_ID_WEB="$web_id")
[[ -n "$ios_id" ]] && FLUTTER_DEFINE_ARGS+=(--dart-define=GOOGLE_CLIENT_ID_IOS="$ios_id")
[[ -n "$android_id" ]] && FLUTTER_DEFINE_ARGS+=(--dart-define=GOOGLE_CLIENT_ID_ANDROID="$android_id")
[[ -n "$kakao_key" ]] && FLUTTER_DEFINE_ARGS+=(--dart-define=KAKAO_NATIVE_APP_KEY="$kakao_key")

cleanup() {
  if [[ -n "$WATCH_PID" ]] && kill -0 "$WATCH_PID" 2>/dev/null; then
    kill "$WATCH_PID" 2>/dev/null || true
  fi
  rm -f "$FLUTTER_PID_FILE"
}
trap cleanup EXIT INT TERM

if ! nc -z 127.0.0.1 "$(bash "$ROOT/scripts/read-dev-port.sh")" 2>/dev/null; then
  echo "[flutter] API not listening yet. Run: npm run dev:next  (or yarn app)" >&2
fi

if [[ "${FLUTTER_AUTO_RELOAD:-1}" != "0" ]]; then
  rm -f "$FLUTTER_PID_FILE"
  export FLUTTER_PID_FILE
  node "$ROOT/scripts/flutter-auto-reload.mjs" &
  WATCH_PID=$!
  echo "[flutter] auto reload on (poll 1s, throttle ${FLUTTER_RELOAD_THROTTLE_MS:-2000}ms)"
fi

cd "$ROOT/flutter_app"
DEVICE="${FLUTTER_DEVICE:-chrome}"
flutter run -d "$DEVICE" \
  --pid-file="$FLUTTER_PID_FILE" \
  "${FLUTTER_DEFINE_ARGS[@]}" \
  "$@"
