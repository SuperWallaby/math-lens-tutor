#!/usr/bin/env bash
# 우열 라이트 — Android AAB 릴리스 (OAuth dart-define 포함)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
API="${API_BASE_URL:-https://study-hazel-six.vercel.app}"

# shellcheck source=flutter-oauth-defines.sh
source "$ROOT/scripts/flutter-oauth-defines.sh"

DEFINE=(
  --dart-define=APP_VARIANT=lite
  --dart-define="API_BASE_URL=${API}"
)
flutter_oauth_append_defines DEFINE

cd "$ROOT/flutter_app"
exec flutter build appbundle --release --flavor lite "${DEFINE[@]}"
