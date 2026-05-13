export const env = {
  /** 예: https://YOUR_RESOURCE.openai.azure.com (끝 슬래시 없어도 됨) */
  azureOpenAiEndpoint: process.env.AZURE_OPENAI_ENDPOINT,
  azureOpenAiApiKey: process.env.AZURE_OPENAI_API_KEY,
  /** Azure 포털의 배포 이름(예: gpt-4o). 비전 모델 배포여야 이미지 분석 가능 */
  azureOpenAiDeployment: process.env.AZURE_OPENAI_DEPLOYMENT,
  /** 모드별 배포(미설정 시 `AZURE_OPENAI_DEPLOYMENT`로 대체). 비전+텍스트 JSON 모두 가능한 배포 권장 */
  azureOpenAiDeploymentFast: process.env.AZURE_OPENAI_DEPLOYMENT_FAST,
  azureOpenAiDeploymentBalanced: process.env.AZURE_OPENAI_DEPLOYMENT_BALANCED,
  azureOpenAiDeploymentAccurate: process.env.AZURE_OPENAI_DEPLOYMENT_ACCURATE,
  /** 미설정 시 밸런스→패스트→기본 순으로 폴백. 풀이 사진 분석(비전) 전용 배포 */
  azureOpenAiDeploymentVision: process.env.AZURE_OPENAI_DEPLOYMENT_VISION,
  azureOpenAiApiVersion:
    process.env.AZURE_OPENAI_API_VERSION ?? "2024-08-01-preview",
  /**
   * Chat Completions 대신 Responses API 를 쓸 **배포 이름** 목록(쉼표 구분).
   * 예: `gpt-5.4-pro,my-gpt5-exact` 또는 접두사 와일드카드 `gpt-5.*` 형태는 `gpt-5*` 로 prefix 매칭.
   * 비어 있으면 코드가 `gpt-5` 포함 배포명을 자동 감지합니다.
   */
  azureOpenAiResponsesDeployments: process.env.AZURE_OPENAI_RESPONSES_DEPLOYMENTS,
  /** GPT-5 등: `/openai/v1/responses` 쿼리 api-version (기본 preview) */
  azureOpenAiResponsesApiVersion:
    process.env.AZURE_OPENAI_RESPONSES_API_VERSION ?? "preview",
  /**
   * Responses API 호출 시 `reasoning.effort` (gpt-5 권장).
   * 허용: low | medium | high
   */
  azureOpenAiReasoningEffort:
    process.env.AZURE_OPENAI_REASONING_EFFORT ?? "medium",
  mongodbUri: process.env.MONGODB_URI,
  mongodbDbName: process.env.MONGODB_DB_NAME ?? "math_lens_tutor",
};

export function hasMongoConfig() {
  return Boolean(env.mongodbUri);
}
