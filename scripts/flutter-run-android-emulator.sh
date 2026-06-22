#!/usr/bin/env bash
# Android 에뮬레이터 → 호스트 PC localhost (10.0.2.2)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
port="$(bash "$ROOT/scripts/read-dev-port.sh")"
API_BASE="${FLUTTER_API_BASE_URL:-http://10.0.2.2:${port}}"

cd "$ROOT/flutter_app"
exec flutter run --dart-define=API_BASE_URL="$API_BASE" "$@"
