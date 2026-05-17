# shellcheck shell=bash
# release.sh 에서 source — 직접 실행하지 마세요.

release_root() {
  cd "$(dirname "${BASH_SOURCE[0]}")/.."
  pwd
}

release_ensure_java() {
  # shell의 JAVA_HOME 이 깨져 있어도 java -version 은 될 수 있음 → Gradle 은 JAVA_HOME 만 봄
  # shellcheck source=env-java.sh
  source "$(dirname "${BASH_SOURCE[0]}")/env-java.sh"
}

release_read_version() {
  local pubspec
  pubspec="$(release_root)/pubspec.yaml"
  local line
  line="$(grep -E '^version:' "$pubspec" | head -1)"
  # version: 1.0.2+4
  RELEASE_VERSION_NAME="${line#version: }"
  RELEASE_VERSION_NAME="${RELEASE_VERSION_NAME// /}"
  RELEASE_VERSION="${RELEASE_VERSION_NAME%%+*}"
  RELEASE_BUILD="${RELEASE_VERSION_NAME##*+}"
}

release_bump_pubspec() {
  local mode="${1:-build}"
  release_read_version
  local major minor patch build
  IFS='.' read -r major minor patch <<<"$RELEASE_VERSION"
  build="$RELEASE_BUILD"

  case "$mode" in
    build)
      build=$((build + 1))
      ;;
    patch)
      patch=$((patch + 1))
      build=$((build + 1))
      ;;
    minor)
      minor=$((minor + 1))
      patch=0
      build=$((build + 1))
      ;;
    *)
      echo "알 수 없는 bump 모드: $mode (build|patch|minor)" >&2
      return 1
      ;;
  esac

  local new_ver="${major}.${minor}.${patch}+${build}"
  local pubspec
  pubspec="$(release_root)/pubspec.yaml"
  if [[ "$(uname)" == Darwin ]]; then
    sed -i '' "s/^version: .*/version: ${new_ver}/" "$pubspec"
  else
    sed -i "s/^version: .*/version: ${new_ver}/" "$pubspec"
  fi
  echo "버전 갱신: ${RELEASE_VERSION_NAME} → ${new_ver}"
  release_read_version
}

release_copy_artifacts() {
  local root
  root="$(release_root)"
  release_read_version
  local out_dir="${root}/releases/${RELEASE_VERSION_NAME}"
  mkdir -p "$out_dir"

  local ipa_src="${root}/build/ios/ipa/math_lens_tutor.ipa"
  local aab_src="${root}/build/app/outputs/bundle/release/app-release.aab"
  local apk_src="${root}/build/app/outputs/flutter-apk/app-release.apk"
  local base="wooyeol-${RELEASE_VERSION}-build${RELEASE_BUILD}"

  [[ -f "$ipa_src" ]] && cp "$ipa_src" "${out_dir}/${base}.ipa"
  [[ -f "$aab_src" ]] && cp "$aab_src" "${out_dir}/${base}.aab"
  [[ -f "$apk_src" ]] && cp "$apk_src" "${out_dir}/${base}.apk"

  RELEASE_OUT_DIR="$(cd "$out_dir" && pwd)"

  echo ""
  echo "── 릴리스 복사본 ──"
  echo "   ${RELEASE_OUT_DIR}"
  ls -lah "$RELEASE_OUT_DIR" 2>/dev/null || true
}

# macOS: Finder에서 releases 폴더 열기. OPEN_FINDER=0 이면 생략.
release_reveal_output() {
  if [[ -z "${RELEASE_OUT_DIR:-}" ]]; then
    return 0
  fi
  echo ""
  echo "📁 산출물 폴더:"
  echo "   ${RELEASE_OUT_DIR}"
  if [[ "${OPEN_FINDER:-1}" == "0" ]]; then
    return 0
  fi
  if [[ "$(uname)" == Darwin ]] && command -v open >/dev/null 2>&1; then
    open "${RELEASE_OUT_DIR}"
    echo "   (Finder에서 열었습니다)"
  fi
}
