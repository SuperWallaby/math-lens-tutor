#!/usr/bin/env bash
# 로컬에서 응답 중인 Study API 포트를 stdout 으로 출력 (없으면 exit 1).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

is_up() {
  bash "$ROOT/scripts/is-study-api-up.sh" "$1"
}

candidates=()

if [[ -f "$ROOT/.dev-local-port" ]]; then
  candidates+=("$(tr -d '[:space:]' < "$ROOT/.dev-local-port")")
fi

candidates+=("$(bash "$ROOT/scripts/pick-dev-port.sh")")

candidates+=(3001 3000)

while IFS= read -r port; do
  [[ -n "$port" ]] && candidates+=("$port")
done < <(
  lsof -iTCP -sTCP:LISTEN -P -n 2>/dev/null \
    | awk '/node/ { split($9, a, ":"); print a[length(a)] }' \
    | sort -un \
    | head -40
)

seen=""
for port in "${candidates[@]}"; do
  [[ "$port" =~ ^[0-9]+$ ]] || continue
  [[ " $seen " == *" $port "* ]] && continue
  seen="$seen $port"
  if is_up "$port"; then
    echo "$port"
    exit 0
  fi
done

exit 1
