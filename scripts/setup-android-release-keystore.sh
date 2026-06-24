#!/usr/bin/env bash
# Play Store 업로드용 release keystore + key.properties 생성 (1회)
#
#   bash scripts/setup-android-release-keystore.sh
#
# 비밀번호를 직접 지정:
#   ANDROID_KEYSTORE_PASSWORD='...' ANDROID_KEY_PASSWORD='...' bash scripts/setup-android-release-keystore.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ANDROID="$ROOT/flutter_app/android"
KEYSTORE_DIR="$ANDROID/keystore"
KEYSTORE="$KEYSTORE_DIR/upload-keystore.jks"
PROPS="$ANDROID/key.properties"

if [[ -f "$KEYSTORE" ]]; then
  echo "이미 keystore 있음: $KEYSTORE"
  echo "key.properties 만 없으면 example 참고해서 수동 작성."
  exit 0
fi

mkdir -p "$KEYSTORE_DIR"

STORE_PASS="${ANDROID_KEYSTORE_PASSWORD:-}"
KEY_PASS="${ANDROID_KEY_PASSWORD:-}"

if [[ -z "$STORE_PASS" ]]; then
  STORE_PASS="$(openssl rand -base64 24 | tr -dc 'A-Za-z0-9' | head -c 24)"
  echo "▶ storePassword (key.properties에 저장): $STORE_PASS"
fi
if [[ -z "$KEY_PASS" ]]; then
  KEY_PASS="$STORE_PASS"
fi

keytool -genkeypair -v \
  -keystore "$KEYSTORE" \
  -storepass "$STORE_PASS" \
  -keypass "$KEY_PASS" \
  -alias upload \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000 \
  -dname "CN=Wooyeol, OU=Neo Project, O=Neo Project, L=Seoul, ST=Seoul, C=KR"

cat >"$PROPS" <<EOF
storePassword=$STORE_PASS
keyPassword=$KEY_PASS
keyAlias=upload
storeFile=keystore/upload-keystore.jks
EOF

chmod 600 "$PROPS" 2>/dev/null || true

echo ""
echo "✓ keystore: $KEYSTORE"
echo "✓ key.properties: $PROPS"
echo ""
echo "SHA-1 (Google OAuth / 카카오 등록용):"
keytool -list -v -keystore "$KEYSTORE" -alias upload -storepass "$STORE_PASS" 2>/dev/null \
  | grep -E 'SHA1:|SHA256:' || true
echo ""
echo "⚠ keystore + key.properties 백업 필수 (분실 시 Play 업데이트 불가)"
echo "다음: yarn flutter:release:bump"
