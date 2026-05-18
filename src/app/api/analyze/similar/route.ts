import { NextResponse } from "next/server";
import { parseAnalyzeQualityMode } from "@/lib/analyze-mode";
import {
  generateSimilarProblems,
  hasAzureOpenAiConfig,
} from "@/lib/azure";
import { getRequestUserId } from "@/lib/request";
import { sampleAnalysis, sampleProblemSet } from "@/lib/sample";
import { studyLog } from "@/lib/server-log";
import { saveProblemSet, saveSubmission } from "@/lib/store";
import {
  generatedProblemSetSchema,
  solutionAnalysisSchema,
} from "@/lib/types";
import type { SolutionSubmission } from "@/lib/types";

export const runtime = "nodejs";
export const maxDuration = 120;

export async function POST(request: Request) {
  const userId = getRequestUserId(request);

  try {
    const body = (await request.json()) as Record<string, unknown>;
    const submissionId = String(body.submissionId ?? "").trim();
    const problemSetId = String(body.problemSetId ?? "").trim();
    const imageName = String(body.imageName ?? "upload.jpg");
    const imageUrl = (body.imageUrl as string | null) ?? null;
    const textDeploymentName = String(body.textDeploymentName ?? "").trim();
    const visionDeploymentName = String(body.visionDeploymentName ?? "").trim();
    const qualityMode = parseAnalyzeQualityMode(
      body.qualityMode as string | null,
    );

    if (!submissionId || !problemSetId || !textDeploymentName) {
      return NextResponse.json(
        { error: "submissionId, problemSetId, textDeploymentName이 필요합니다." },
        { status: 400 },
      );
    }

    const analysis = solutionAnalysisSchema.parse(body.analysis);
    const fromVisionOcrOnly = body.fromVisionOcrOnly === true;
    const azureConfigured = hasAzureOpenAiConfig();
    const usedSample = !azureConfigured;

    studyLog("analyze:similar", "POST start", {
      submissionId,
      problemSetId,
      fromVisionOcrOnly,
    });

    const problemSet = azureConfigured
      ? await generateSimilarProblems(analysis, submissionId, {
          deploymentName: textDeploymentName,
          mode: qualityMode,
          problemSetId,
          fromVisionOcrOnly,
        })
      : {
          ...sampleProblemSet,
          id: problemSetId,
          submissionId,
        };

    const parsedSet = generatedProblemSetSchema.parse(problemSet);
    await saveProblemSet(parsedSet);

    if (fromVisionOcrOnly) {
      return NextResponse.json({
        submissionId,
        problemSetId,
        problemSet: parsedSet,
        usedSample,
      });
    }

    const modelMeta = {
      visionModel: usedSample ? "(샘플)" : visionDeploymentName,
      textModel: usedSample ? "(샘플)" : textDeploymentName,
      qualityMode,
      isSample: usedSample,
    };

    const submission: SolutionSubmission = {
      id: submissionId,
      userId,
      imageUrl,
      imageName,
      createdAt: new Date().toISOString(),
      analysis,
      modelMeta,
    };

    await saveSubmission(submission);

    return NextResponse.json({
      submissionId,
      problemSetId,
      qualityMode,
      submission,
      problemSet: parsedSet,
    });
  } catch (error) {
    studyLog("analyze:similar", "failed", {
      error: error instanceof Error ? error.message : String(error),
    });
    return NextResponse.json(
      { error: "유사 문제 생성 중 오류가 발생했습니다." },
      { status: 500 },
    );
  }
}
