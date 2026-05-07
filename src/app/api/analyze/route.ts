import { randomUUID } from "crypto";
import { NextResponse } from "next/server";
import { parseAnalyzeQualityMode } from "@/lib/analyze-mode";
import {
  analyzeAndGenerateProblemSetUnified,
  analyzeSolutionImage,
  generateSimilarProblems,
  hasAzureOpenAiConfig,
  resolveAzureDeploymentName,
} from "@/lib/azure";
import { GENERIC_ANALYZE_ERROR, logApiError } from "@/lib/api-errors";
import { getRequestUserId } from "@/lib/request";
import {
  saveProblemSet,
  saveSubmission,
  uploadSolutionImage,
} from "@/lib/store";
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
      const deploymentName = resolveAzureDeploymentName(qualityMode);
      if (!deploymentName) {
        return NextResponse.json(
          {
            error:
              "Azure OpenAI 배포 이름이 없습니다. AZURE_OPENAI_DEPLOYMENT 또는 모드별 AZURE_OPENAI_DEPLOYMENT_* 환경 변수를 설정해 주세요.",
          },
          { status: 500 },
        );
      }
    }

    const submissionId = randomUUID();
    const deploymentName =
      resolveAzureDeploymentName(qualityMode) ?? "unused";

    let imageUrl: string | null;
    let analysis: SolutionSubmission["analysis"];
    let problemSet: GeneratedProblemSet;

    if (qualityMode === "fast") {
      const problemSetId = randomUUID();
      const [uploadedUrl, bundle] = await Promise.all([
        uploadSolutionImage(file, userId),
        analyzeAndGenerateProblemSetUnified(
          file,
          submissionId,
          problemSetId,
          deploymentName,
        ),
      ]);
      imageUrl = uploadedUrl;
      analysis = bundle.analysis;
      problemSet = bundle.problemSet;
    } else {
      const [uploadedUrl, analysisResult] = await Promise.all([
        uploadSolutionImage(file, userId),
        analyzeSolutionImage(file, { deploymentName, mode: qualityMode }),
      ]);
      imageUrl = uploadedUrl;
      analysis = analysisResult;
      problemSet = await generateSimilarProblems(analysis, submissionId, {
        deploymentName,
        mode: qualityMode,
      });
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
