#!/usr/bin/env bash
# Flutter 스토어 릴리스 일괄 빌드 (IPA + AAB + APK) + releases/ 폴더에 복사
#
# 사용법 (레포 루트 또는 flutter_app 어디서든):
#   ./flutter_app/scripts/release.sh              # iOS + Android 전부
#   ./flutter_app/scripts/release.sh ios
#   ./flutter_app/scripts/release.sh android
#   ./flutter_app/scripts/release.sh --bump build # 빌드번호만 +1 후 전부 빌드
#   ./flutter_app/scripts/release.sh --bump patch # 패치 + 빌드 +1
#
# npm (레포 루트): yarn flutter:release
#
# 환경 변수:
#   API_BASE_URL  (기본 https://study-alpha-rosy.vercel.app)
#   SKIP_PUB_GET=1  flutter pub get 생략
#   OPEN_FINDER=0   빌드 후 Finder 자동 열기 끄기 (기본: 열기, macOS만)
#
# iOS: Xcode Runner → Signing Team 필요 (로컬 Mac)
# Android: JAVA_HOME 깨져 있으면 jdk-20 자동 시도
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# Gradle/Android 빌드 전에 깨진 JAVA_HOME 교정 (예: /usr/local/opt/openjdk@21)
# shellcheck source=env-java.sh
source "${SCRIPT_DIR}/env-java.sh"
# shellcheck source=_release-common.sh
source "${SCRIPT_DIR}/_release-common.sh"

cd "$(release_root)"

API="${API_BASE_URL:-https://study-alpha-rosy.vercel.app}"
TARGET="all"
BUMP=""

usage() {
  sed -n '2,18p' "$0" | sed 's/^# \{0,1\}//'
  exit "${1:-0}"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help) usage 0 ;;
    --bump)
      BUMP="${2:-build}"
      shift 2
      ;;
    ios|android|all)
      TARGET="$1"
      shift
      ;;
    *)
      echo "알 수 없는 인자: $1" >&2
      usage 1
      ;;
  esac
done

if [[ -n "$BUMP" ]]; then
  release_bump_pubspec "$BUMP"
fi

release_read_version
echo "════════════════════════════════════════"
echo " 우열 Flutter 릴리스  ${RELEASE_VERSION_NAME}"
echo " API_BASE_URL=${API}"
echo " 대상: ${TARGET}"
echo "════════════════════════════════════════"

release_ensure_java

if [[ "${SKIP_PUB_GET:-}" != "1" ]]; then
  flutter pub get
fi

DEFINE=(--dart-define="API_BASE_URL=${API}")

build_ios() {
  echo ""
  echo "▶ iOS IPA"
  flutter build ipa --release "${DEFINE[@]}"
}

build_android() {
  echo ""
  echo "▶ Android AAB + APK"
  # AAB는 strip 경고가 나와도 산출물이 생기는 경우가 많음
  set +e
  flutter build appbundle --release "${DEFINE[@]}"
  local aab_status=$?
  set -e
  if [[ $aab_status -ne 0 ]]; then
    if [[ -f build/app/outputs/bundle/release/app-release.aab ]]; then
      echo "⚠ appbundle 경고/비정상 종료였으나 AAB 파일이 있어 계속합니다."
    else
      exit $aab_status
    fi
  fi
  flutter build apk --release "${DEFINE[@]}"
}

case "$TARGET" in
  ios) build_ios ;;
  android) build_android ;;
  all)
    build_ios
    build_android
    ;;
esac

release_copy_artifacts
release_reveal_output

echo ""
echo "완료. 업로드:"
echo "  iOS  → Transporter / App Store Connect ( .ipa )"
echo "  Play → ${RELEASE_VERSION_NAME} 폴더의 .aab"
