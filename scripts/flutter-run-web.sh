#!/usr/bin/env bash
# Chrome Flutter + read-dev-port 기반 API URL + optional auto hot reload
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
API_BASE="${FLUTTER_API_BASE_URL:-$(bash "$ROOT/scripts/dev-api-url.sh")}"
FLUTTER_PID_FILE="$ROOT/.flutter-run.pid"
WATCH_PID=""
FLUTTER_DEFINE_ARGS=(--dart-define="API_BASE_URL=$API_BASE")

# shellcheck source=flutter-oauth-defines.sh
source "$ROOT/scripts/flutter-oauth-defines.sh"
flutter_oauth_append_defines FLUTTER_DEFINE_ARGS
# shellcheck source=flutter-local-defines.sh
source "$ROOT/scripts/flutter-local-defines.sh"
flutter_append_local_defines FLUTTER_DEFINE_ARGS

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
WEB_PORT="$(bash "$ROOT/scripts/ensure-flutter-web-port.sh")"
echo "[flutter] Web http://localhost:${WEB_PORT}  API ${API_BASE}" >&2
flutter run -d "$DEVICE" \
  --web-port="$WEB_PORT" \
  --pid-file="$FLUTTER_PID_FILE" \
  "${FLUTTER_DEFINE_ARGS[@]}" \
  "$@"
