#!/usr/bin/env bash
# shellcheck shell=bash
# `dev/local-defines.json` 이 있으면 --dart-define-from-file 을 배열에 추가합니다.
#
# 사용 (flutter_app/ 에서 실행):
#   source "$ROOT/scripts/flutter-local-defines.sh"
#   ARGS=(...)
#   flutter_append_local_defines ARGS

flutter_local_defines_file() {
  local root="${FLUTTER_LOCAL_DEFINES_ROOT:-}"
  if [[ -z "$root" ]]; then
    root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  fi
  printf '%s/flutter_app/dev/local-defines.json' "$root"
}

flutter_append_local_defines() {
  local arr_name="$1"
  local file
  file="$(flutter_local_defines_file)"
  [[ -f "$file" ]] || return 0
  eval "${arr_name}+=(--dart-define-from-file=dev/local-defines.json)"
}
