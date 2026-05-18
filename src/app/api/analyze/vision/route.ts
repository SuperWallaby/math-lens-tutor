import { randomUUID } from "crypto";
import { NextResponse } from "next/server";
import {
  assertAzureDeploymentsConfigured,
  resolveAnalyzeDeploymentsFromForm,
} from "@/lib/analyze-deployments";
import { partialAnalysisFromVision } from "@/lib/analyze-partial";
import {
  extractSolutionImageVision,
  hasAzureOpenAiConfig,
} from "@/lib/azure";
import { getRequestUserId } from "@/lib/request";
import { sampleAnalysis } from "@/lib/sample";
import { studyLog } from "@/lib/server-log";
import { uploadSolutionImage } from "@/lib/store";

export const runtime = "nodejs";
export const maxDuration = 120;

export async function POST(request: Request) {
  const userId = getRequestUserId(request);
  const azureConfigured = hasAzureOpenAiConfig();

  try {
    const formData = await request.formData();
    const file = formData.get("image");
    if (!(file instanceof File) || file.size === 0) {
      return NextResponse.json(
        { error: "풀이 사진 파일을 첨부해 주세요." },
        { status: 400 },
      );
    }

    const deployments = resolveAnalyzeDeploymentsFromForm(formData);
    const configError = assertAzureDeploymentsConfigured(
      azureConfigured,
      deployments,
    );
    if (configError) return configError;

    const submissionId = randomUUID();
    const problemSetId = randomUUID();

    studyLog("analyze:vision", "POST start", {
      submissionId,
      size: file.size,
      visionDeployment: deployments.visionDeploymentName,
    });

    if (!azureConfigured) {
      const imageUrl = await uploadSolutionImage(file, userId);
      const vision = {
        problemText: sampleAnalysis.problemText,
        extractedStudentAnswer: sampleAnalysis.extractedStudentAnswer,
        solutionSteps: sampleAnalysis.solutionSteps,
        imageClarityScore: 1,
        extractionConfidence: 1,
      };
      return NextResponse.json({
        submissionId,
        problemSetId,
        imageUrl,
        imageName: file.name,
        vision,
        analysis: partialAnalysisFromVision(vision),
        ...deployments,
      });
    }

    const [imageUrl, vision] = await Promise.all([
      uploadSolutionImage(file, userId),
      extractSolutionImageVision(file, {
        deploymentName: deployments.visionDeploymentName,
      }),
    ]);

    return NextResponse.json({
      submissionId,
      problemSetId,
      imageUrl,
      imageName: file.name,
      vision,
      analysis: partialAnalysisFromVision(vision),
      ...deployments,
    });
  } catch (error) {
    studyLog("analyze:vision", "failed", {
      error: error instanceof Error ? error.message : String(error),
    });
    return NextResponse.json(
      { error: "사진을 읽는 중 오류가 발생했습니다." },
      { status: 500 },
    );
  }
}
