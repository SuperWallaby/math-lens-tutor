#!/usr/bin/env bash
# Azure OpenAI에 "빠른 / 밸런스 / 정확"용 배포 3개를 만듭니다.
# 사전: Azure CLI 로그인(`az login`), Cognitive Services OpenAI 리소스 존재.
#
# 사용법:
#   export AZ_RG="my-rg"
#   export AZ_OPENAI_ACCOUNT="my-openai"
#   ./scripts/azure-openai-deploy-tiers.sh
#
# 모델 이름·버전은 구독/리전에서 허용하는 조합으로 바꿉니다.
# 참고: https://learn.microsoft.com/azure/ai-services/openai/how-to/create-resource

set -euo pipefail

: "${AZ_RG:?Set AZ_RG (resource group)}"
: "${AZ_OPENAI_ACCOUNT:?Set AZ_OPENAI_ACCOUNT (OpenAI resource name)}"

# 리전별 사용 가능 모델은 `az cognitiveservices model list` 등으로 확인
FAST_MODEL="${FAST_MODEL:-gpt-4o-mini}"
FAST_VERSION="${FAST_VERSION:-2024-07-18}"
BAL_MODEL="${BAL_MODEL:-gpt-4o}"
BAL_VERSION="${BAL_VERSION:-2024-08-06}"
ACC_MODEL="${ACC_MODEL:-gpt-4o}"
ACC_VERSION="${ACC_VERSION:-2024-08-06}"

SKU_NAME="${SKU_NAME:-Standard}"
CAPACITY="${CAPACITY:-20}"

deploy() {
  local deployment_name="$1"
  local model_name="$2"
  local model_version="$3"
  echo ">>> Creating deployment: ${deployment_name} (${model_name} ${model_version})"
  az cognitiveservices account deployment create \
    --resource-group "${AZ_RG}" \
    --name "${AZ_OPENAI_ACCOUNT}" \
    --deployment-name "${deployment_name}" \
    --model-name "${model_name}" \
    --model-version "${model_version}" \
    --model-format OpenAI \
    --sku-name "${SKU_NAME}" \
    --sku-capacity "${CAPACITY}"
}

deploy "study-fast" "${FAST_MODEL}" "${FAST_VERSION}"
deploy "study-balanced" "${BAL_MODEL}" "${BAL_VERSION}"
deploy "study-accurate" "${ACC_MODEL}" "${ACC_VERSION}"

echo
echo "끝. Vercel/로컬 .env 에 다음을 맞춰 넣으세요:"
echo "  AZURE_OPENAI_DEPLOYMENT_FAST=study-fast"
echo "  AZURE_OPENAI_DEPLOYMENT_BALANCED=study-balanced"
echo "  AZURE_OPENAI_DEPLOYMENT_ACCURATE=study-accurate"
echo "  (또는 기존처럼 AZURE_OPENAI_DEPLOYMENT 하나만 두면 세 모드가 동일 배포를 씁니다.)"
