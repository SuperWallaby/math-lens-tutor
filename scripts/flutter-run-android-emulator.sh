#!/usr/bin/env bash
# Android 에뮬레이터 → 호스트 PC localhost (10.0.2.2)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
port="$(bash "$ROOT/scripts/read-dev-port.sh")"
API_BASE="${FLUTTER_API_BASE_URL:-http://10.0.2.2:${port}}"

cd "$ROOT/flutter_app"

FLUTTER_DEFINE_ARGS=(
  --flavor full
  --dart-define=API_BASE_URL="$API_BASE"
)
# shellcheck source=flutter-oauth-defines.sh
source "$ROOT/scripts/flutter-oauth-defines.sh"
flutter_oauth_append_defines FLUTTER_DEFINE_ARGS
# shellcheck source=flutter-local-defines.sh
source "$ROOT/scripts/flutter-local-defines.sh"
flutter_append_local_defines FLUTTER_DEFINE_ARGS

exec flutter run "${FLUTTER_DEFINE_ARGS[@]}" "$@"
