#!/usr/bin/env bash
# App Store / TestFlight용 IPA. Xcode에서 Runner 타깃 Signing Team 설정 후 실행하세요.
set -euo pipefail
cd "$(dirname "$0")/.."
API="${API_BASE_URL:-https://study-alpha-rosy.vercel.app}"
echo "API_BASE_URL=$API"
flutter pub get
flutter build ipa --dart-define="API_BASE_URL=$API"
echo "완료. IPA 위치는 위 로그의 출력 경로를 확인하거나:"
echo "  build/ios/ipa/*.ipa"
