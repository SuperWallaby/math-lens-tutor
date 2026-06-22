#!/usr/bin/env bash
# Flutter 앱 스토어 스크린샷 일괄 캡처 (iPhone + iPad)
#
# 사용 (레포 루트):
#   ./scripts/capture-flutter-store-screenshots.sh
#   IPHONE_DEVICE="iPhone 16 Pro Max" IPAD_DEVICE="iPad Pro 13-inch (M5)" ./scripts/capture-flutter-store-screenshots.sh
#
# 결과:
#   screen-shots/flutter-iphone-raw/*.png
#   screen-shots/flutter-ipad-raw/*.png
#   screen-shots/ios-app-store-6.7in-1290x2796/   (iPhone 리사이즈)
#   screen-shots/ios-ipad-12.9-2048x2732/        (iPad 리사이즈)
#
# Play Store용은 6.7" 세트를 그대로 쓰거나 phone 폴더에서 1080×1920 등으로 추가 리사이즈.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT/flutter_app"

API_BASE="${API_BASE_URL:-https://study-hazel-six.vercel.app}"
IPHONE_RAW="$ROOT/screen-shots/flutter-iphone-raw"
IPAD_RAW="$ROOT/screen-shots/flutter-ipad-raw"
IPHONE_OUT="$ROOT/screen-shots/ios-app-store-6.7in-1290x2796"
IPAD_OUT="$ROOT/screen-shots/ios-ipad-12.9-2048x2732"
mkdir -p "$IPHONE_RAW" "$IPAD_RAW" "$IPHONE_OUT" "$IPAD_OUT"

IPHONE_DEVICE="${IPHONE_DEVICE:-iPhone 16 Pro Max}"
IPAD_DEVICE="${IPAD_DEVICE:-iPad Pro 13-inch (M5)}"

SCREENS=(
  "home:01-student-home.png"
  "upload:02-upload.png"
  "analysis:03-analysis.png"
  "practice:04-practice.png"
  "parent-home:05-parent-home.png"
  "parent-explain:06-parent-explain.png"
)

capture_on_device() {
  local device="$1"
  local out_dir="$2"
  local first_wait="${3:-120}"
  local wait_sec="${4:-50}"

  xcrun simctl boot "$device" 2>/dev/null || true
  open -a Simulator
  sleep 4

  local idx=0
  for entry in "${SCREENS[@]}"; do
    local mode="${entry%%:*}"
    local filename="${entry##*:}"
    local wait="$wait_sec"
    if [[ $idx -eq 0 ]]; then
      wait="$first_wait"
    fi
    idx=$((idx + 1))

    echo ""
    echo "=== [$device] STORE_SCREENSHOT=$mode -> $filename (${wait}s) ==="
    flutter run -d "$device" \
      --dart-define=STORE_SCREENSHOT="$mode" \
      --dart-define=API_BASE_URL="$API_BASE" \
      --release \
      --no-pub &
    local fr_pid=$!
    sleep "$wait"
    flutter screenshot -o "$out_dir/$filename" || true
    kill -INT "$fr_pid" 2>/dev/null || true
    wait "$fr_pid" 2>/dev/null || true
    sleep 3
  done
}

if ! xcrun simctl list devices available | grep -q "$IPHONE_DEVICE"; then
  echo "iPhone 기기 '$IPHONE_DEVICE' 없음. IPHONE_DEVICE 로 지정하세요."
  xcrun simctl list devices available | grep -i iphone | head -12 || true
  exit 1
fi

if ! xcrun simctl list devices available | grep -q "$IPAD_DEVICE"; then
  echo "iPad 기기 '$IPAD_DEVICE' 없음. IPAD_DEVICE 로 지정하세요."
  xcrun simctl list devices available | grep -i ipad | head -12 || true
  exit 1
fi

echo "▶ iPhone 캡처: $IPHONE_DEVICE"
capture_on_device "$IPHONE_DEVICE" "$IPHONE_RAW" 120 50

echo ""
echo "▶ iPad 캡처: $IPAD_DEVICE"
capture_on_device "$IPAD_DEVICE" "$IPAD_RAW" 120 50

if command -v python3 >/dev/null 2>&1; then
  echo ""
  echo "▶ iPhone → App Store 6.7\" (1290×2796)"
  for f in "$IPHONE_RAW"/*.png; do
    [[ -f "$f" ]] || continue
    python3 "$ROOT/screen-shots/resize_one.py" \
      --src "$f" \
      --dst "$IPHONE_OUT/$(basename "$f")" \
      --w 1290 --h 2796
  done

  echo "▶ iPad → App Store 12.9\" (2048×2732)"
  python3 "$ROOT/screen-shots/resize_ipad_flutter_to_12_9.py" \
    --src "$IPAD_RAW" \
    --dst "$IPAD_OUT" || true
else
  echo "python3 없음 — 원본만 저장됨"
fi

echo ""
echo "완료"
echo "  iPhone 원본: $IPHONE_RAW"
echo "  iPad 원본:   $IPAD_RAW"
echo "  iOS 6.7\":   $IPHONE_OUT"
echo "  iPad 12.9\": $IPAD_OUT"
