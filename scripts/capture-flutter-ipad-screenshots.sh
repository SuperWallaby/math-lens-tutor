#!/usr/bin/env bash
# 시뮬레이터에서 STORE_SCREENSHOT 모드로 앱을 띄운 뒤 flutter screenshot 저장.
# 사용: repo 루트 또는 scripts에서 — Xcode Simulator·Flutter·CocoaPods 필요.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT/flutter_app"

API_BASE="${API_BASE_URL:-https://study-alpha-rosy.vercel.app}"
OUT="$ROOT/screen-shots/flutter-ipad-simulator"
STORE_OUT="$ROOT/screen-shots/ios-ipad-12.9-2048x2732"
mkdir -p "$OUT" "$STORE_OUT"

DEVICE="${IPAD_DEVICE:-iPad Pro 13-inch (M5)}"
if ! xcrun simctl list devices available | grep -q "$DEVICE"; then
  echo "기기 '$DEVICE' 를 찾을 수 없습니다. IPAD_DEVICE 로 이름을 지정하세요."
  xcrun simctl list devices available | grep -i ipad | head -12 || true
  exit 1
fi

xcrun simctl boot "$DEVICE" 2>/dev/null || true
open -a Simulator
sleep 4

capture_one() {
  local mode="$1"
  local filename="$2"
  local wait_sec="${3:-55}"
  echo "=== STORE_SCREENSHOT=$mode (${wait_sec}s) -> $filename ==="
  flutter run -d "$DEVICE" \
    --dart-define=STORE_SCREENSHOT="$mode" \
    --dart-define=API_BASE_URL="$API_BASE" \
    --no-pub &
  local fr_pid=$!
  sleep "$wait_sec"
  flutter screenshot -o "$OUT/$filename" || true
  kill -INT "$fr_pid" 2>/dev/null || true
  wait "$fr_pid" 2>/dev/null || true
  sleep 3
}

# 첫 빌드가 길어질 수 있음
capture_one home 01-home.png 120
capture_one upload 02-upload.png 45
capture_one analysis 03-analysis.png 45
capture_one practice 04-practice-demo.png 45
capture_one dashboard 05-dashboard.png 45

echo "원본: $OUT"
if command -v python3 >/dev/null 2>&1; then
  python3 "$ROOT/screen-shots/resize_ipad_flutter_to_12_9.py" \
    --src "$OUT" \
    --dst "$STORE_OUT" || echo "(선택) 리사이즈 스크립트 실패 — 원본만 사용"
else
  echo "python3 없음 — App Store 픽셀 맞춤 생략"
fi
echo "App Store 규격(가능 시): $STORE_OUT"
