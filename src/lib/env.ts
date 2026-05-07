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
  azureOpenAiApiVersion:
    process.env.AZURE_OPENAI_API_VERSION ?? "2024-08-01-preview",
  mongodbUri: process.env.MONGODB_URI,
  mongodbDbName: process.env.MONGODB_DB_NAME ?? "math_lens_tutor",
};

export function hasMongoConfig() {
  return Boolean(env.mongodbUri);
}
