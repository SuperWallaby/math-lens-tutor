#!/usr/bin/env bash
# onboarding + 3d 아이콘 PNG → WebP (품질 82). 원본 PNG는 삭제.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="${ROOT}/flutter_app"
QUALITY="${WEBP_QUALITY:-82}"

if ! command -v cwebp >/dev/null 2>&1; then
  echo "cwebp 가 필요합니다 (brew install webp)"
  exit 1
fi

convert_dir() {
  local dir="$1"
  local count=0
  while IFS= read -r png; do
    local webp="${png%.png}.webp"
    cwebp -quiet -q "$QUALITY" "$png" -o "$webp"
    rm -f "$png"
    count=$((count + 1))
  done < <(find "$dir" -name '*.png' -type f | sort)
  echo "  ${dir}: ${count} files → WebP"
}

echo "==> WebP 변환 (q=${QUALITY})"
convert_dir "${APP}/assets/onboarding"
convert_dir "${APP}/assets/icons/3d"
echo "Done."
