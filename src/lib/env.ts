export const env = {
  /** 예: https://YOUR_RESOURCE.openai.azure.com (끝 슬래시 없어도 됨) */
  azureOpenAiEndpoint: process.env.AZURE_OPENAI_ENDPOINT,
  azureOpenAiApiKey: process.env.AZURE_OPENAI_API_KEY,
  /** Azure 포털의 배포 이름(예: gpt-4o). 비전 모델 배포여야 이미지 분석 가능 */
  azureOpenAiDeployment: process.env.AZURE_OPENAI_DEPLOYMENT,
  azureOpenAiApiVersion:
    process.env.AZURE_OPENAI_API_VERSION ?? "2024-08-01-preview",
  mongodbUri: process.env.MONGODB_URI,
  mongodbDbName: process.env.MONGODB_DB_NAME ?? "math_lens_tutor",
};

export function hasMongoConfig() {
  return Boolean(env.mongodbUri);
}
