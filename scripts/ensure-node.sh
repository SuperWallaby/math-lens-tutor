#!/usr/bin/env bash
# Next.js 16+ needs Node >= 20.9. Source from dev scripts or run standalone.
set -euo pipefail

ENSURE_NODE_ROOT="${ENSURE_NODE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"

node_version_ok() {
  command -v node >/dev/null 2>&1 || return 1
  node -e "
    const v = process.versions.node.split('.').map(Number);
    const ok = v[0] > 20 || (v[0] === 20 && v[1] >= 9);
    process.exit(ok ? 0 : 1);
  "
}

_load_nvm() {
  export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
  if [[ -s "$NVM_DIR/nvm.sh" ]]; then
    # shellcheck disable=SC1091
    source "$NVM_DIR/nvm.sh"
    return 0
  fi
  return 1
}

_try_nvm_use() {
  local spec="$1"
  if nvm use "$spec" >/dev/null 2>&1 && node_version_ok; then
    echo "[dev] Node $(node -v) ← nvm use ${spec}" >&2
    return 0
  fi
  return 1
}

ensure_node_for_dev() {
  if node_version_ok; then
    return 0
  fi

  local before
  before="$(node -v 2>/dev/null || echo 'not found')"
  echo "[dev] Node ${before} is too old for Next.js (need >= 20.9). Trying nvm..." >&2

  if ! _load_nvm; then
    echo "[dev] nvm not found. Install Node >= 20.9 or add it to PATH." >&2
    return 1
  fi

  if [[ -f "$ENSURE_NODE_ROOT/.nvmrc" ]]; then
    _try_nvm_use "$(tr -d '[:space:]' < "$ENSURE_NODE_ROOT/.nvmrc")" && return 0
  fi

  for spec in 22 20 default 20.9 lts/*; do
    _try_nvm_use "$spec" && return 0
  done

  echo "[dev] Could not activate Node >= 20.9. Run: nvm install 22 && nvm use 22" >&2
  return 1
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  ensure_node_for_dev
else
  ensure_node_for_dev || exit 1
fi
