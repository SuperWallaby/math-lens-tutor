#!/usr/bin/env bash
# Cloudflare R2 버킷 1개(neo-study-uploads) 생성 + .env.local 갱신 안내
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ENV_FILE="${ROOT}/.env.local"
BUCKET="${R2_BUCKET_NAME:-neo-study-uploads}"

echo "== Cloudflare R2 setup =="
echo "Bucket: ${BUCKET}"
echo ""

if ! command -v wrangler >/dev/null 2>&1; then
  echo "wrangler CLI가 없습니다. npm i -g wrangler 후 wrangler login"
  exit 1
fi

echo "→ wrangler whoami"
if ! wrangler whoami; then
  echo ""
  echo "wrangler 로그인이 필요합니다: wrangler login"
  exit 1
fi

echo ""
echo "→ wrangler r2 bucket create ${BUCKET}"
if wrangler r2 bucket create "${BUCKET}" 2>&1; then
  echo "버킷 생성 완료 (또는 이미 존재)"
else
  echo ""
  echo "버킷 생성 API 호출 실패. 대시보드에서 수동 생성:"
  echo "  Cloudflare Dashboard → R2 → Create bucket → ${BUCKET}"
fi

echo ""
echo "다음: R2 S3 API 토큰 발급"
echo "  Dashboard → R2 → Manage R2 API Tokens → Create API token"
echo "  - 권한: Object Read & Write"
echo "  - 버킷: ${BUCKET} (또는 All buckets)"
echo "  - Account ID, Access Key ID, Secret Access Key 복사"
echo ""
echo "선택: 공개 URL이 필요하면 버킷 Settings → Public access → r2.dev 도메인 활성화"
echo "  R2_PUBLIC_BASE_URL=https://pub-xxxx.r2.dev"
echo ""

append_env() {
  local key="$1"
  local value="$2"
  if grep -q "^${key}=" "${ENV_FILE}" 2>/dev/null; then
    return
  fi
  printf '\n%s=%s\n' "${key}" "${value}" >> "${ENV_FILE}"
}

touch "${ENV_FILE}"
append_env "R2_BUCKET_NAME" "${BUCKET}"

if [[ -n "${R2_ACCOUNT_ID:-}" ]]; then
  append_env "R2_ACCOUNT_ID" "${R2_ACCOUNT_ID}"
fi
if [[ -n "${R2_ACCESS_KEY_ID:-}" ]]; then
  append_env "R2_ACCESS_KEY_ID" "${R2_ACCESS_KEY_ID}"
fi
if [[ -n "${R2_SECRET_ACCESS_KEY:-}" ]]; then
  append_env "R2_SECRET_ACCESS_KEY" "${R2_SECRET_ACCESS_KEY}"
fi
if [[ -n "${R2_PUBLIC_BASE_URL:-}" ]]; then
  append_env "R2_PUBLIC_BASE_URL" "${R2_PUBLIC_BASE_URL}"
fi

echo "→ ${ENV_FILE} 에 R2_BUCKET_NAME=${BUCKET} 반영 (키 3개는 토큰 발급 후 채우세요)"
echo ""
echo "예시:"
echo "  R2_ACCOUNT_ID=<Cloudflare Account ID>"
echo "  R2_ACCESS_KEY_ID=<R2 API token access key>"
echo "  R2_SECRET_ACCESS_KEY=<R2 API token secret>"
echo "  R2_BUCKET_NAME=${BUCKET}"
echo "  # R2_PUBLIC_BASE_URL=https://pub-xxxx.r2.dev"
