#!/usr/bin/env bash
# Flutter Web release build + Playwright store screenshots (Dispatch-style).
#
# Usage (repo root):
#   ./scripts/capture-appstore-screenshots.sh
#   ./scripts/capture-appstore-screenshots.sh --only parent
#   FLUTTER_APP_URL=http://127.0.0.1:5050 ./scripts/capture-appstore-screenshots.sh --skip-build
#
# Output: artifacts/store-screenshots/{iphone-6.5,android-phone,...}/*.png
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT/flutter_app"

PORT="${FLUTTER_WEB_PORT:-5050}"
BASE="http://127.0.0.1:${PORT}"
API_BASE="${API_BASE_URL:-https://study-hazel-six.vercel.app}"
LOG="$ROOT/artifacts/store-screenshots/flutter-web-server.log"
PIDFILE="$ROOT/artifacts/.flutter-web-screenshots.pid"
SKIP_BUILD=false

for arg in "$@"; do
  if [[ "$arg" == "--skip-build" ]]; then
    SKIP_BUILD=true
  fi
done

CAPTURE_ARGS=()
for arg in "$@"; do
  [[ "$arg" == "--skip-build" ]] && continue
  CAPTURE_ARGS+=("$arg")
done

cleanup() {
  if [[ -f "$PIDFILE" ]]; then
    kill "$(cat "$PIDFILE")" 2>/dev/null || true
    rm -f "$PIDFILE"
  fi
}
trap cleanup EXIT

mkdir -p "$ROOT/artifacts/store-screenshots"

if [[ "${FLUTTER_APP_URL:-}" == "" ]]; then
  if [[ "$SKIP_BUILD" == false ]]; then
    echo "▶ flutter build web --release (API_BASE_URL=$API_BASE)"
    flutter build web --release --dart-define=API_BASE_URL="$API_BASE"
  fi

  echo "▶ Static server on $BASE"
  python3 -m http.server "$PORT" --bind 127.0.0.1 --directory build/web \
    >"$LOG" 2>&1 &
  echo $! >"$PIDFILE"

  echo "Waiting for $BASE ..."
  for i in $(seq 1 60); do
    if curl -sf "$BASE/" >/dev/null 2>&1; then
      echo "Flutter web ready (${i}s)"
      break
    fi
    if ! kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
      echo "Static server exited early. Log:"
      tail -40 "$LOG" || true
      exit 1
    fi
    sleep 1
    if [[ "$i" -eq 60 ]]; then
      echo "Timeout waiting for Flutter web"
      tail -40 "$LOG" || true
      exit 1
    fi
  done

  echo "Warming up Flutter (first CanvasKit load)..."
  curl -sf "${BASE}/?store_screenshot=home" >/dev/null 2>&1 || true
  sleep 6
  export FLUTTER_APP_URL="$BASE"
else
  echo "▶ Using existing FLUTTER_APP_URL=$FLUTTER_APP_URL"
fi

cd "$ROOT"
node scripts/capture-appstore-screenshots.mjs "${CAPTURE_ARGS[@]}"
