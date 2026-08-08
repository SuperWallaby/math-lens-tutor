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
  bash "$ROOT/scripts/get-lan-ip.sh"
}

wait_for_study_api() {
  local port="$1"
  local pid="${2:-}"
  local tries="${3:-90}"
  local i
  for ((i = 1; i <= tries; i++)); do
    if [[ -n "$pid" ]] && ! kill -0 "$pid" 2>/dev/null; then
      echo "Next.js exited before Study API was ready on port ${port}." >&2
      wait "$pid" 2>/dev/null || true
      return 1
    fi
    if bash "$ROOT/scripts/is-study-api-up.sh" "$port" 2>/dev/null; then
      return 0
    fi
    sleep 1
  done
  echo "Study API did not respond on port ${port} within ${tries}s." >&2
  return 1
}

# 실기기 선택: 유선(USB)만 대상. 무선(wireless) 기기는 절대 고르지 않는다.
# 같은 유선끼리는 iPhone → Android 순. 유선 실기기가 없으면 아무것도 출력하지
# 않아 Chrome 폴백으로 넘어간다. 결과는 "id\tname\tplatform".
# (flutter devices 사람용 출력의 (wireless) 태그로 판별 — --machine JSON 엔 없음)
find_target_device() {
  cd "$ROOT/flutter_app"
  node <<'NODE'
const { execFileSync } = require("node:child_process");

let text = "";
try {
  text = execFileSync("flutter", ["devices"], {
    encoding: "utf8",
    stdio: ["ignore", "pipe", "ignore"],
  });
} catch {
  process.exit(0);
}

const candidates = [];
for (const line of text.split("\n")) {
  if (!line.includes(" • ")) continue;
  const parts = line.split(" • ").map((s) => s.trim());
  if (parts.length < 3) continue;
  const meta = parts[0];
  const id = parts[1];
  const platformField = parts[2];

  // 무선 기기 제외 — 유선(USB)만 사용
  if (/\(wireless\)/i.test(meta)) continue;
  // 에뮬레이터/시뮬레이터 제외
  if (id.startsWith("emulator-")) continue;
  if (/\((emulator|simulator)\)/i.test(line)) continue;

  let plat = "";
  if (platformField.startsWith("android")) plat = "android";
  else if (platformField === "ios") plat = "ios";
  else continue; // desktop/web 제외

  const name = meta.replace(/\s*\((wireless|mobile)\)/gi, "").trim();
  candidates.push({ id, name, plat });
}

// 유선끼리 우선순위: iPhone(0) < Android(1)
const rank = (c) => (c.plat === "ios" ? 0 : 1);
candidates.sort((a, b) => rank(a) - rank(b));

const phone = candidates[0];
if (phone) {
  process.stdout.write(`${phone.id}\t${phone.name}\t${phone.plat}`);
}
NODE
}

# 주어진 device id 의 플랫폼("ios"/"android"/"") 을 출력.
device_platform() {
  local target_id="$1"
  cd "$ROOT/flutter_app"
  TARGET_ID="$target_id" node <<'NODE'
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
const d = devices.find((x) => x.id === process.env.TARGET_ID);
if (d) {
  const p = String(d.targetPlatform || "");
  process.stdout.write(p.startsWith("android") ? "android" : (p === "ios" ? "ios" : ""));
}
NODE
}

flutter_dart_defines() {
  local api_base="$1"
  FLUTTER_DEFINE_ARGS=()

  # shellcheck source=flutter-oauth-defines.sh
  source "$ROOT/scripts/flutter-oauth-defines.sh"
  flutter_oauth_append_defines FLUTTER_DEFINE_ARGS
  # shellcheck source=flutter-local-defines.sh
  source "$ROOT/scripts/flutter-local-defines.sh"
  flutter_append_local_defines FLUTTER_DEFINE_ARGS
  # local-defines.json 보다 나중 — 실기기 LAN IP 가 127.0.0.1 을 덮어쓰지 않도록
  FLUTTER_DEFINE_ARGS+=(--dart-define=API_BASE_URL="$api_base")
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
  local web_port
  web_port="$(bash "$ROOT/scripts/ensure-flutter-web-port.sh")"
  start_flutter_auto_reload
  echo "=== Flutter web http://localhost:${web_port} ===" >&2
  flutter run -d "$device" \
    --web-port="$web_port" \
    --pid-file="$FLUTTER_PID_FILE" \
    "${FLUTTER_DEFINE_ARGS[@]}" \
    "$@"
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

API_PORT="$(bash "$ROOT/scripts/ensure-dev-port-free.sh" "${API_PORT:-}")"
export PORT="$API_PORT"
bash "$ROOT/scripts/write-dev-port.sh" "$API_PORT"
API_LOCAL="http://127.0.0.1:${API_PORT}"
LAN_IP="$(bash "$ROOT/scripts/get-lan-ip.sh")"
API_LAN="$(bash "$ROOT/scripts/get-flutter-api-url.sh" "$API_PORT")"

echo "=== Starting Next.js (${API_LOCAL}, LAN ${API_LAN}, ip ${LAN_IP}) ==="
bash "$ROOT/scripts/next-dev.sh" &
NEXT_PID=$!

wait_for_study_api "$API_PORT" "$NEXT_PID" || exit 1

API_LOCAL="http://127.0.0.1:${API_PORT}"
LAN_IP="$(bash "$ROOT/scripts/get-lan-ip.sh")"
API_LAN="$(bash "$ROOT/scripts/get-flutter-api-url.sh" "$API_PORT")"

FLUTTER_DEVICE="${FLUTTER_DEVICE:-}"
FLUTTER_DEVICE_NAME=""
FLUTTER_DEVICE_PLATFORM="${FLUTTER_DEVICE_PLATFORM:-}"

if [[ -z "$FLUTTER_DEVICE" ]]; then
  dev_info="$(find_target_device || true)"
  if [[ -n "$dev_info" ]]; then
    IFS=$'\t' read -r FLUTTER_DEVICE FLUTTER_DEVICE_NAME FLUTTER_DEVICE_PLATFORM <<<"$dev_info"
  fi
elif [[ -z "$FLUTTER_DEVICE_PLATFORM" ]]; then
  # 사용자가 FLUTTER_DEVICE 를 직접 지정한 경우 플랫폼을 조회해 flavor 판단.
  FLUTTER_DEVICE_PLATFORM="$(device_platform "$FLUTTER_DEVICE" || true)"
fi

cd "$ROOT/flutter_app"

if [[ -n "$FLUTTER_DEVICE" ]]; then
  # Android 실기기는 .local(mDNS)을 해석하지 못하므로 LAN IP를 직접 사용.
  if [[ "$FLUTTER_DEVICE_PLATFORM" == "android" ]]; then
    API_BASE="http://${LAN_IP}:${API_PORT}"
  else
    API_BASE="$(bash "$ROOT/scripts/get-flutter-api-url.sh" "$API_PORT")"
  fi
  user_api="${FLUTTER_API_BASE_URL:-}"
  if [[ -n "$user_api" && "$user_api" != "$API_BASE" ]]; then
    if [[ "$user_api" == *192.0.0.* ]]; then
      echo "=== NOTE: FLUTTER_API_BASE_URL=${user_api} 무시 (실기기에서 192.0.0.x 접속 불가) ===" >&2
      echo "===       → ${API_BASE} 사용 ===" >&2
    else
      API_BASE="$user_api"
    fi
  fi
  if [[ "$API_BASE" == *127.0.0.1* || "$API_BASE" == *192.0.0.* ]]; then
    echo "=== WARNING: 실기기는 ${API_BASE} 로 API 접속이 막힐 수 있습니다 ===" >&2
    echo "===          yarn app 만 실행하고 Hot Restart 말고 전체 재시작하세요 ===" >&2
  fi
  # Android 는 product flavor(full/lite)가 필수 — full 로 실행.
  FLUTTER_RUN_EXTRA=()
  if [[ "$FLUTTER_DEVICE_PLATFORM" == "android" ]]; then
    FLUTTER_RUN_EXTRA+=(--flavor full)
  fi
  echo "=== Flutter → ${FLUTTER_DEVICE_NAME:-$FLUTTER_DEVICE} [${FLUTTER_DEVICE_PLATFORM:-ios}] (API ${API_BASE}) ==="
  flutter_dart_defines "$API_BASE"
  run_flutter "$FLUTTER_DEVICE" ${FLUTTER_RUN_EXTRA[@]+"${FLUTTER_RUN_EXTRA[@]}"} "$@"
  exit $?
fi

API_BASE="${FLUTTER_API_BASE_URL:-$API_LOCAL}"
echo "=== No phone found (iPhone/Android). Flutter → Chrome (API ${API_BASE}) ==="
flutter_dart_defines "$API_BASE"
run_flutter chrome "$@"
exit $?
