#!/usr/bin/env bash
# .dev-local-port + flutter dart-define 파일 갱신
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
port="${1:?port required}"

echo "$port" > "$ROOT/.dev-local-port"
mkdir -p "$ROOT/flutter_app/dev"
cat > "$ROOT/flutter_app/dev/local-defines.json" <<JSON
{
  "port": ${port},
  "API_BASE_URL": "http://127.0.0.1:${port}"
}
JSON
