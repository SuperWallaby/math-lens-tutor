import { NextResponse } from "next/server";
import { parseAnalyzeQualityMode } from "@/lib/analyze-mode";
import { getRequestUserId } from "@/lib/request";
import { studyLog } from "@/lib/server-log";
import { getProblemSet, saveSubmission } from "@/lib/store";
import {
  generatedProblemSetSchema,
  solutionAnalysisSchema,
} from "@/lib/types";
import type { SolutionSubmission } from "@/lib/types";

export const runtime = "nodejs";
export const maxDuration = 30;

/** phased 분석: 튜터·유사문제 병렬 후 제출 기록 저장 */
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
    const usedSample = body.usedSample === true;

    if (!submissionId || !problemSetId) {
      return NextResponse.json(
        { error: "submissionId, problemSetId가 필요합니다." },
        { status: 400 },
      );
    }

    const analysis = solutionAnalysisSchema.parse(body.analysis);
    const storedSet = await getProblemSet(problemSetId);
    const problemSet = storedSet
      ? generatedProblemSetSchema.parse(storedSet)
      : body.problemSet
        ? generatedProblemSetSchema.parse(body.problemSet)
        : null;

    if (!problemSet) {
      return NextResponse.json(
        { error: "유사 문제 세트를 찾을 수 없습니다." },
        { status: 404 },
      );
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

    studyLog("analyze:finalize", "POST save", { submissionId, problemSetId });
    await saveSubmission(submission);

    return NextResponse.json({
      submissionId,
      problemSetId,
      qualityMode,
      submission,
      problemSet,
    });
  } catch (error) {
    studyLog("analyze:finalize", "failed", {
      error: error instanceof Error ? error.message : String(error),
    });
    return NextResponse.json(
      { error: "결과 저장 중 오류가 발생했습니다." },
      { status: 500 },
    );
  }
}
