import type { AnalyzeQualityMode } from "./analyze-mode";
import { parseAnalyzeQualityMode } from "./analyze-mode";
import {
  resolveAzureDeploymentName,
  resolveVisionDeploymentName,
} from "./azure";
import {
  buildTextDeploymentCandidateList,
  buildVisionDeploymentCandidateList,
  pickAllowedDeployment,
} from "./model-deployment-options";

export type ResolvedAnalyzeDeployments = {
  qualityMode: AnalyzeQualityMode;
  textDeploymentName: string;
  visionDeploymentName: string;
};

export function resolveAnalyzeDeploymentsFromForm(
  formData: FormData,
): ResolvedAnalyzeDeployments {
  const qualityMode = parseAnalyzeQualityMode(formData.get("qualityMode"));
  const textFallback = resolveAzureDeploymentName(qualityMode);
  const visionFallback = resolveVisionDeploymentName();
  const textCandidates = buildTextDeploymentCandidateList();
  const visionCandidates = buildVisionDeploymentCandidateList();

  const textDeploymentName =
    pickAllowedDeployment(
      formData.get("textDeployment"),
      textCandidates,
      textFallback,
    ) ?? "unused";
  const visionDeploymentName =
    pickAllowedDeployment(
      formData.get("visionDeployment"),
      visionCandidates,
      visionFallback,
    ) ?? textDeploymentName;

  return { qualityMode, textDeploymentName, visionDeploymentName };
}

export function assertAzureDeploymentsConfigured(
  azureConfigured: boolean,
  deployments: ResolvedAnalyzeDeployments,
): Response | null {
  if (!azureConfigured) return null;
  if (!resolveAzureDeploymentName(deployments.qualityMode)) {
    return Response.json(
      {
        error:
          "Azure OpenAI 배포 이름이 없습니다. AZURE_OPENAI_DEPLOYMENT 또는 모드별 AZURE_OPENAI_DEPLOYMENT_* 환경 변수를 설정해 주세요.",
      },
      { status: 500 },
    );
  }
  if (!resolveVisionDeploymentName()) {
    return Response.json(
      {
        error:
          "비전용 배포가 없습니다. AZURE_OPENAI_DEPLOYMENT_BALANCED 등 비전을 지원하는 배포를 설정하거나 AZURE_OPENAI_DEPLOYMENT_VISION 을 지정해 주세요.",
      },
      { status: 500 },
    );
  }
  return null;
}
