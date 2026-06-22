#!/usr/bin/env bash
# 사용 가능한 로컬 dev API 포트를 stdout 으로 출력 (기본: 3100–3999 랜덤 시도).
set -euo pipefail

MIN_PORT="${DEV_PORT_MIN:-3100}"
MAX_PORT="${DEV_PORT_MAX:-3999}"

if [[ -n "${API_PORT:-}" ]]; then
  echo "$API_PORT"
  exit 0
fi

if [[ -n "${DEV_API_PORT:-}" ]]; then
  echo "$DEV_API_PORT"
  exit 0
fi

port_in_use() {
  nc -z 127.0.0.1 "$1" 2>/dev/null
}

# 랜덤 시도
for _ in $(seq 1 40); do
  port=$((MIN_PORT + RANDOM % (MAX_PORT - MIN_PORT + 1)))
  if ! port_in_use "$port"; then
    echo "$port"
    exit 0
  fi
done

# 순차 스캔
for ((port = MIN_PORT; port <= MAX_PORT; port++)); do
  if ! port_in_use "$port"; then
    echo "$port"
    exit 0
  fi
done

echo "No free dev port in ${MIN_PORT}-${MAX_PORT}" >&2
exit 1
