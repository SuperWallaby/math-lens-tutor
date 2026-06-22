#!/usr/bin/env bash
# Kakao Developers → Android 플랫폼 등록용 키 해시 출력
set -euo pipefail

print_hash() {
  local label="$1"
  local keystore="$2"
  local alias="$3"
  local storepass="$4"
  local keypass="$5"

  if [[ ! -f "$keystore" ]]; then
    echo "${label}: keystore 없음 (${keystore})"
    return 0
  fi

  local hash
  hash="$(
    keytool -exportcert -alias "$alias" -keystore "$keystore" \
      -storepass "$storepass" -keypass "$keypass" 2>/dev/null \
      | openssl sha1 -binary \
      | openssl base64
  )"
  echo "${label}: ${hash}"
}

echo "=== Kakao Android 키 해시 ==="
echo "카카오 개발자 콘솔 → 내 애플리케이션 → 플랫폼 → Android → 키 해시에 등록"
echo ""
print_hash "Debug (로컬 개발)" \
  "${HOME}/.android/debug.keystore" \
  androiddebugkey android android
echo ""
echo "Release 는 Play App Signing / 업로드 keystore 기준으로 다를 수 있습니다."
echo "release keystore 경로를 알고 있다면:"
echo "  keytool -exportcert -alias YOUR_ALIAS -keystore YOUR.jks | openssl sha1 -binary | openssl base64"
