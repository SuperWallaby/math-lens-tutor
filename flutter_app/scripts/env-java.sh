# shellcheck shell=bash
# Android/Gradle용 JAVA_HOME 정리. 사용: source flutter_app/scripts/env-java.sh
#
# 셸에 JAVA_HOME=/usr/local/opt/openjdk@21 처럼 깨진 값이 있으면 Gradle만 실패합니다.

release_java_pick_home() {
  local d
  if [[ -n "${JAVA_HOME:-}" && -x "${JAVA_HOME}/bin/java" ]]; then
    echo "$JAVA_HOME"
    return 0
  fi
  if command -v /usr/libexec/java_home >/dev/null 2>&1; then
    d="$(/usr/libexec/java_home 2>/dev/null || true)"
    if [[ -n "$d" && -x "$d/bin/java" ]]; then
      echo "$d"
      return 0
    fi
  fi
  for d in \
    /Library/Java/JavaVirtualMachines/jdk-20.jdk/Contents/Home \
    /opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home \
    /opt/homebrew/opt/openjdk/libexec/openjdk.jdk/Contents/Home; do
    if [[ -x "$d/bin/java" ]]; then
      echo "$d"
      return 0
    fi
  done
  return 1
}

_fix_java_home() {
  local picked
  if ! picked="$(release_java_pick_home)"; then
    echo "ERROR: 사용 가능한 JDK를 찾지 못했습니다. Android Studio JDK 또는 jdk-20 설치 후 다시 시도하세요." >&2
    return 1
  fi
  if [[ "${JAVA_HOME:-}" != "$picked" ]]; then
    if [[ -n "${JAVA_HOME:-}" ]]; then
      echo "JAVA_HOME 수정: ${JAVA_HOME} → ${picked}" >&2
    fi
    export JAVA_HOME="$picked"
  fi
  export PATH="$JAVA_HOME/bin:$PATH"
}

_fix_java_home
