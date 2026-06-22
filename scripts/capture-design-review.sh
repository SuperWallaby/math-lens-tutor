#!/usr/bin/env bash
# Flutter design-review captures (mobile viewport, Playwright).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT/flutter_app"

PORT="${DESIGN_REVIEW_PORT:-8080}"
BASE="http://127.0.0.1:${PORT}"
LOG="$ROOT/design-review/flutter-web-server.log"
PIDFILE="$ROOT/design-review/.flutter-web.pid"

cleanup() {
  if [[ -f "$PIDFILE" ]]; then
    kill "$(cat "$PIDFILE")" 2>/dev/null || true
    rm -f "$PIDFILE"
  fi
}
trap cleanup EXIT

echo "Starting Flutter web-server on :${PORT}..."
flutter run -d web-server \
  --web-port="$PORT" \
  --dart-define=API_BASE_URL="$(bash "$ROOT/scripts/dev-api-url.sh")" \
  >"$LOG" 2>&1 &
echo $! >"$PIDFILE"

echo "Waiting for $BASE ..."
for i in $(seq 1 90); do
  if curl -sf "$BASE/" >/dev/null 2>&1; then
    echo "Flutter web ready (${i}s)"
    break
  fi
  if ! kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
    echo "Flutter web-server exited early. Log:"
    tail -40 "$LOG" || true
    exit 1
  fi
  sleep 2
  if [[ "$i" -eq 90 ]]; then
    echo "Timeout waiting for Flutter web-server"
    tail -40 "$LOG" || true
    exit 1
  fi
done

echo "Warming up Flutter web (first compile)..."
curl -sf "${BASE}/?design_review=student_hub__first_visit" >/dev/null 2>&1 || true
sleep 35

cd "$ROOT"
FLUTTER_WEB_URL="$BASE" node scripts/capture-design-review.mjs "$@"
