#!/usr/bin/env bash
# shellcheck shell=bash
# .env.local 에서 OAuth 관련 --dart-define 값을 읽어 배열에 추가합니다.
#
# 사용:
#   source "$ROOT/scripts/flutter-oauth-defines.sh"
#   DEFINE=(--dart-define=API_BASE_URL=...)
#   flutter_oauth_append_defines DEFINE

flutter_oauth_env_file() {
  if [[ -n "${FLUTTER_ENV_FILE:-}" ]]; then
    printf '%s' "$FLUTTER_ENV_FILE"
    return
  fi
  local root
  root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  printf '%s/.env.local' "$root"
}

flutter_oauth_load_env_var() {
  local key="$1"
  local file
  file="$(flutter_oauth_env_file)"
  [[ -f "$file" ]] || return 0
  local line
  line="$(grep -E "^${key}=" "$file" | tail -1 || true)"
  [[ -n "$line" ]] || return 0
  printf '%s' "${line#*=}"
}

flutter_oauth_append_defines() {
  local arr_name="$1"
  local web_id ios_id android_id kakao_key
  web_id="$(flutter_oauth_load_env_var GOOGLE_CLIENT_ID_WEB)"
  ios_id="$(flutter_oauth_load_env_var GOOGLE_CLIENT_ID_IOS)"
  android_id="$(flutter_oauth_load_env_var GOOGLE_CLIENT_ID_ANDROID)"
  kakao_key="$(flutter_oauth_load_env_var KAKAO_NATIVE_APP_KEY)"

  [[ -n "$web_id" ]] && eval "${arr_name}+=(--dart-define=\"GOOGLE_CLIENT_ID_WEB=${web_id}\")"
  [[ -n "$ios_id" ]] && eval "${arr_name}+=(--dart-define=\"GOOGLE_CLIENT_ID_IOS=${ios_id}\")"
  [[ -n "$android_id" ]] && eval "${arr_name}+=(--dart-define=\"GOOGLE_CLIENT_ID_ANDROID=${android_id}\")"
  [[ -n "$kakao_key" ]] && eval "${arr_name}+=(--dart-define=\"KAKAO_NATIVE_APP_KEY=${kakao_key}\")"
}
