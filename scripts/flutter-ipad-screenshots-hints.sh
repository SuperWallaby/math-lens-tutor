#!/usr/bin/env bash
# iPad 시뮬레이터에서 Flutter 앱을 띄운 뒤, 다른 터미널에서 `flutter screenshot`으로 캡처하세요.
# 자동 일괄 캡처: repo 루트에서 `./scripts/capture-flutter-ipad-screenshots.sh`
# (STORE_SCREENSHOT=home|upload|analysis|practice|dashboard + 2048×2732 리사이즈)
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT/flutter_app"

echo "=== 사용 가능한 iOS 시뮬레이터 (iPad) ==="
xcrun simctl list devices available | grep -i "iPad" | head -20 || true
echo ""
echo "=== Flutter가 보는 기기 ==="
flutter devices

echo ""
echo "1) Xcode → Open Developer Tool → Simulator 로 시뮬레이터를 연 뒤,"
echo "   메뉴 Window → Device and Simulators 에서 iPad Pro 12.9\" 또는 13\" 을 선택해 부팅하세요."
echo ""
echo "2) 이 터미널에서 앱 실행 (아래에서 디바이스 이름만 본인 환경에 맞게 바꿈):"
echo "   cd flutter_app"
echo "   flutter run -d \"iPad Pro 13-inch (M4)\" --dart-define=API_BASE_URL=https://study-alpha-rosy.vercel.app"
echo "   (이름은 \`flutter devices\` 출력과 동일해야 합니다.)"
echo ""
echo "3) 앱이 뜨고 화면을 원하는 상태로 만든 뒤, 다른 터미널에서:"
echo "   cd flutter_app"
echo "   mkdir -p ../screen-shots/flutter-ipad-simulator"
echo "   flutter screenshot -o ../screen-shots/flutter-ipad-simulator/01-home.png"
echo ""
echo "스크린샷 크기는 시뮬레이터 기기 해상도를 따릅니다."
echo "App Store Connect에 요구하는 픽셀이 맞지 않으면, 캡처 후 Preview/sips 로 리사이즈하세요."
