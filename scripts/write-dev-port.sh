#!/usr/bin/env bash
# .dev-local-port + flutter dart-define 파일 갱신
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
port="${1:?port required}"

echo "$port" > "$ROOT/.dev-local-port"
mkdir -p "$ROOT/flutter_app/dev"
# port 만 저장 — API_BASE_URL 은 yarn app 이 --dart-define 로 LAN IP 를 넣음
cat > "$ROOT/flutter_app/dev/local-defines.json" <<JSON
{
  "port": ${port}
}
JSON
