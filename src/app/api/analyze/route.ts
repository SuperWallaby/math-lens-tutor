import { randomUUID } from "crypto";
import { NextResponse } from "next/server";
import { parseAnalyzeQualityMode } from "@/lib/analyze-mode";
import {
  analyzeSolutionImage,
  generateSimilarProblems,
  hasAzureOpenAiConfig,
  refineSolutionAnalysisForAccurateMode,
  resolveAzureDeploymentName,
  resolveVisionDeploymentName,
} from "@/lib/azure";
import { GENERIC_ANALYZE_ERROR, logApiError } from "@/lib/api-errors";
import { getRequestUserId } from "@/lib/request";
import {
  saveProblemSet,
  saveSubmission,
  uploadSolutionImage,
} from "@/lib/store";
import { sampleAnalysis, sampleProblemSet } from "@/lib/sample";
import type { GeneratedProblemSet, SolutionSubmission } from "@/lib/types";

export const runtime = "nodejs";

export async function POST(request: Request) {
  const userId = getRequestUserId(request);

  try {
    const formData = (await request.formData()) as unknown as {
      get(name: string): FormDataEntryValue | null;
    };
    const file = formData.get("image");

    if (!(file instanceof File) || file.size === 0) {
      return NextResponse.json(
        { error: "풀이 사진 파일을 첨부해 주세요." },
        { status: 400 },
      );
    }

    const qualityMode = parseAnalyzeQualityMode(formData.get("qualityMode"));

    if (hasAzureOpenAiConfig()) {
      const textDeployment = resolveAzureDeploymentName(qualityMode);
      const visionDeployment = resolveVisionDeploymentName();
      if (!textDeployment) {
        return NextResponse.json(
          {
            error:
              "Azure OpenAI 배포 이름이 없습니다. AZURE_OPENAI_DEPLOYMENT 또는 모드별 AZURE_OPENAI_DEPLOYMENT_* 환경 변수를 설정해 주세요.",
          },
          { status: 500 },
        );
      }
      if (!visionDeployment) {
        return NextResponse.json(
          {
            error:
              "비전용 배포가 없습니다. AZURE_OPENAI_DEPLOYMENT_BALANCED 등 비전을 지원하는 배포를 설정하거나 AZURE_OPENAI_DEPLOYMENT_VISION 을 지정해 주세요.",
          },
          { status: 500 },
        );
      }
    }

    const submissionId = randomUUID();
    const problemSetId = randomUUID();
    const deploymentName =
      resolveAzureDeploymentName(qualityMode) ?? "unused";
    const visionDeploymentName =
      resolveVisionDeploymentName() ?? deploymentName;

    /** 각 분기에서 File.arrayBuffer()를 소비하므로 동일 바이트를 복제해 전달 */
    const raw = await file.arrayBuffer();
    const duplicateInputFile = () =>
      new File([raw.slice(0)], file.name, {
        type: file.type || "application/octet-stream",
      });

    let imageUrl: string | null;
    let analysis: SolutionSubmission["analysis"];
    let problemSet: GeneratedProblemSet;

    if (hasAzureOpenAiConfig()) {
      const [uploadedUrl, analysisResult] = await Promise.all([
        uploadSolutionImage(duplicateInputFile(), userId),
        analyzeSolutionImage(duplicateInputFile(), {
          deploymentName: visionDeploymentName,
          mode: qualityMode,
        }),
      ]);
      imageUrl = uploadedUrl;
      analysis = analysisResult;

      if (qualityMode === "accurate") {
        analysis = await refineSolutionAnalysisForAccurateMode(analysis, {
          deploymentName,
          mode: qualityMode,
        });
      }

      problemSet = await generateSimilarProblems(
        analysis,
        submissionId,
        {
          deploymentName,
          mode: qualityMode,
          problemSetId,
        },
      );
    } else {
      imageUrl = await uploadSolutionImage(duplicateInputFile(), userId);
      analysis = sampleAnalysis;
      problemSet = {
        ...sampleProblemSet,
        id: problemSetId,
        submissionId,
      };
    }

    const submission: SolutionSubmission = {
      id: submissionId,
      userId,
      imageUrl,
      imageName: file.name,
      createdAt: new Date().toISOString(),
      analysis,
    };

    await saveSubmission(submission);
    await saveProblemSet(problemSet);

    return NextResponse.json({
      submissionId: submission.id,
      problemSetId: problemSet.id,
      qualityMode,
      submission,
      problemSet,
    });
  } catch (error) {
    const errorId = await logApiError({
      request,
      route: "/api/analyze",
      userId,
      error,
    });

    return NextResponse.json(
      { error: GENERIC_ANALYZE_ERROR, errorId },
      { status: 500 },
    );
  }
}
