#!/usr/bin/env bash
# Flutter iOS 시뮬레이터를 고정해서 실행합니다. (Flutter/Xcode가 옛 UUID를 잡을 때 완화)
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT/flutter_app"

# 기본: iPhone 17 Pro (환경에 맞게 바꿔도 됨)
DEVICE="${FLUTTER_IOS_DEVICE:-iPhone 17 Pro}"
API_BASE="${FLUTTER_API_BASE_URL:-http://localhost:3000}"

if ! command -v flutter >/dev/null 2>&1; then
  echo "flutter 가 PATH 에 없습니다. 터미널에서 which flutter 로 경로 확인 후 PATH 를 잡거나, 전체 경로로 실행하세요."
  exit 1
fi

echo "=== 시뮬레이터: $DEVICE (바꾸려면 FLUTTER_IOS_DEVICE=... ) ==="
xcrun simctl boot "$DEVICE" 2>/dev/null || true
open -a Simulator
sleep 2

exec flutter run -d "$DEVICE" --dart-define=API_BASE_URL="$API_BASE" "$@"
