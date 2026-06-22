#!/usr/bin/env bash
# Local full-stack dev: Next.js API + Flutter (iPhone first, else Chrome).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

# shellcheck disable=SC1091
source "$ROOT/scripts/ensure-node.sh"

bash "$ROOT/scripts/sync-kakao-native.sh" || true

NEXT_PID=""
WATCH_PID=""
FLUTTER_PID_FILE="$ROOT/.flutter-run.pid"
cleanup() {
  if [[ -n "$WATCH_PID" ]] && kill -0 "$WATCH_PID" 2>/dev/null; then
    kill "$WATCH_PID" 2>/dev/null || true
    wait "$WATCH_PID" 2>/dev/null || true
  fi
  if [[ -n "$NEXT_PID" ]] && kill -0 "$NEXT_PID" 2>/dev/null; then
    kill "$NEXT_PID" 2>/dev/null || true
    wait "$NEXT_PID" 2>/dev/null || true
  fi
  rm -f "$FLUTTER_PID_FILE"
}
trap cleanup EXIT INT TERM

get_lan_ip() {
  local iface ip
  for iface in en0 en1 en2; do
    ip="$(ipconfig getifaddr "$iface" 2>/dev/null || true)"
    if [[ -n "$ip" ]]; then
      echo "$ip"
      return 0
    fi
  done
  echo "127.0.0.1"
}

wait_for_study_api() {
  local port="$1"
  local pid="${2:-}"
  local tries="${3:-90}"
  local i
  for ((i = 1; i <= tries; i++)); do
    if [[ -n "$pid" ]] && ! kill -0 "$pid" 2>/dev/null; then
      if existing="$(bash "$ROOT/scripts/find-study-api-port.sh" 2>/dev/null)"; then
        echo "Next.js exited; reusing Study API on port ${existing}." >&2
        echo "$existing"
        return 0
      fi
      echo "Next.js exited before Study API was ready on port ${port}." >&2
      wait "$pid" 2>/dev/null || true
      return 1
    fi
    if bash "$ROOT/scripts/is-study-api-up.sh" "$port" 2>/dev/null; then
      return 0
    fi
    sleep 1
  done
  if existing="$(bash "$ROOT/scripts/find-study-api-port.sh" 2>/dev/null)"; then
    echo "Port ${port} not ready; reusing Study API on port ${existing}." >&2
    echo "$existing"
    return 0
  fi
  echo "Study API did not respond on port ${port} within ${tries}s." >&2
  return 1
}

find_ios_device() {
  cd "$ROOT/flutter_app"
  node <<'NODE'
const { execFileSync } = require("node:child_process");

let raw = "";
try {
  raw = execFileSync("flutter", ["devices", "--machine"], {
    encoding: "utf8",
    stdio: ["ignore", "pipe", "pipe"],
  });
} catch {
  process.exit(0);
}

let devices;
try {
  devices = JSON.parse(raw);
} catch {
  process.exit(0);
}

const phone = devices.find(
  (d) => d.targetPlatform === "ios" && !d.emulator && d.isSupported,
);

if (phone) {
  process.stdout.write(`${phone.id}\t${phone.name}`);
}
NODE
}

load_env_var() {
  local key="$1"
  local file="$ROOT/.env.local"
  [[ -f "$file" ]] || return 0
  local line
  line="$(grep -E "^${key}=" "$file" | tail -1 || true)"
  [[ -n "$line" ]] || return 0
  printf '%s' "${line#*=}"
}

flutter_dart_defines() {
  local api_base="$1"
  FLUTTER_DEFINE_ARGS=(--dart-define=API_BASE_URL="$api_base")

  local web_id ios_id android_id kakao_key
  web_id="$(load_env_var GOOGLE_CLIENT_ID_WEB)"
  ios_id="$(load_env_var GOOGLE_CLIENT_ID_IOS)"
  android_id="$(load_env_var GOOGLE_CLIENT_ID_ANDROID)"
  kakao_key="$(load_env_var KAKAO_NATIVE_APP_KEY)"

  if [[ -n "$web_id" ]]; then
    FLUTTER_DEFINE_ARGS+=(--dart-define=GOOGLE_CLIENT_ID_WEB="$web_id")
  fi
  if [[ -n "$ios_id" ]]; then
    FLUTTER_DEFINE_ARGS+=(--dart-define=GOOGLE_CLIENT_ID_IOS="$ios_id")
  fi
  if [[ -n "$android_id" ]]; then
    FLUTTER_DEFINE_ARGS+=(--dart-define=GOOGLE_CLIENT_ID_ANDROID="$android_id")
  fi
  if [[ -n "$kakao_key" ]]; then
    FLUTTER_DEFINE_ARGS+=(--dart-define=KAKAO_NATIVE_APP_KEY="$kakao_key")
  fi
}

start_flutter_auto_reload() {
  if [[ "${FLUTTER_AUTO_RELOAD:-1}" == "0" ]]; then
    return 0
  fi
  rm -f "$FLUTTER_PID_FILE"
  export FLUTTER_PID_FILE
  node "$ROOT/scripts/flutter-auto-reload.mjs" &
  WATCH_PID=$!
  echo "=== Auto reload: 저장 시 r/R 자동 (poll 1s, throttle ${FLUTTER_RELOAD_THROTTLE_MS:-2000}ms) ==="
}

run_flutter() {
  local device="$1"
  shift
  start_flutter_auto_reload
  flutter run -d "$device" --pid-file="$FLUTTER_PID_FILE" "${FLUTTER_DEFINE_ARGS[@]}" "$@"
}

if ! command -v flutter >/dev/null 2>&1; then
  echo "flutter 가 PATH 에 없습니다." >&2
  exit 1
fi

LAN_IP="$(get_lan_ip)"
NEXT_PID=""

if [[ "${STUDY_DEV_KEEP_RUNNING:-0}" != "1" ]]; then
  bash "$ROOT/scripts/stop-study-dev-server.sh"
fi

API_PORT="${API_PORT:-$(bash "$ROOT/scripts/pick-dev-port.sh")}"
export PORT="$API_PORT"
bash "$ROOT/scripts/write-dev-port.sh" "$API_PORT"
API_LOCAL="http://127.0.0.1:${API_PORT}"
API_LAN="http://${LAN_IP}:${API_PORT}"

echo "=== Starting Next.js (${API_LOCAL}, LAN ${API_LAN}) ==="
bash "$ROOT/scripts/next-dev.sh" &
NEXT_PID=$!

resolved_port="$(wait_for_study_api "$API_PORT" "$NEXT_PID")" || exit 1
if [[ -n "$resolved_port" && "$resolved_port" != "$API_PORT" ]]; then
  API_PORT="$resolved_port"
  bash "$ROOT/scripts/write-dev-port.sh" "$API_PORT"
fi

API_LOCAL="http://127.0.0.1:${API_PORT}"
API_LAN="http://${LAN_IP}:${API_PORT}"

FLUTTER_DEVICE="${FLUTTER_DEVICE:-}"
FLUTTER_DEVICE_NAME=""

if [[ -z "$FLUTTER_DEVICE" ]]; then
  ios_info="$(find_ios_device || true)"
  if [[ -n "$ios_info" ]]; then
    FLUTTER_DEVICE="${ios_info%%$'\t'*}"
    FLUTTER_DEVICE_NAME="${ios_info#*$'\t'}"
  fi
fi

cd "$ROOT/flutter_app"

if [[ -n "$FLUTTER_DEVICE" ]]; then
  API_BASE="${FLUTTER_API_BASE_URL:-$API_LAN}"
  echo "=== Flutter → ${FLUTTER_DEVICE_NAME:-$FLUTTER_DEVICE} (API ${API_BASE}) ==="
  flutter_dart_defines "$API_BASE"
  run_flutter "$FLUTTER_DEVICE" "$@"
  exit $?
fi

API_BASE="${FLUTTER_API_BASE_URL:-$API_LOCAL}"
echo "=== No iPhone found. Flutter → Chrome (API ${API_BASE}) ==="
flutter_dart_defines "$API_BASE"
run_flutter chrome "$@"
exit $?
