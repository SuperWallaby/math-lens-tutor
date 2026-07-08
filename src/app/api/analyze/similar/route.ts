import { NextResponse } from "next/server";
import { parseAnalyzeQualityMode } from "@/lib/analyze-mode";
import { hasAzureOpenAiConfig } from "@/lib/azure";
import { stripProblemSetForClient } from "@/lib/client-problem";
import { authErrorResponse, resolveActorUserId } from "@/lib/request";
import { withRequestDb } from "@/lib/db-variant";
import { studyLog } from "@/lib/server-log";
import { resolvePracticeProblemSet } from "@/lib/problem-bank";
import { saveProblemSet } from "@/lib/store";
import { findUserById } from "@/lib/users";
import {
  generatedProblemSetSchema,
  solutionAnalysisSchema,
} from "@/lib/types";

export const runtime = "nodejs";
export const maxDuration = 120;

export async function POST(request: Request) {
  return withRequestDb(request, async () => {
  let userId = "anonymous";

  try {
    const actor = await resolveActorUserId(request, { write: true });
    userId = actor.actorUserId;
  } catch (error) {
    const authResponse = authErrorResponse(error);
    if (authResponse) {
      return authResponse;
    }
    return NextResponse.json(
      { error: "유사 문제 생성 중 오류가 발생했습니다." },
      { status: 500 },
    );
  }

  try {
    const body = (await request.json()) as Record<string, unknown>;
    const submissionId = String(body.submissionId ?? "").trim();
    const problemSetId = String(body.problemSetId ?? "").trim();
    const textDeploymentName = String(body.textDeploymentName ?? "").trim();
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

    const user = await findUserById(userId);
    const problemSet = await resolvePracticeProblemSet({
      userId,
      analysis,
      submissionId,
      problemSetId,
      grade: user?.grade,
      generateOptions: {
        deploymentName: textDeploymentName,
        mode: qualityMode,
        fromVisionOcrOnly,
      },
    });

    const parsedSet = generatedProblemSetSchema.parse(problemSet);
    await saveProblemSet(parsedSet);

    return NextResponse.json({
      submissionId,
      problemSetId,
      problemSet: stripProblemSetForClient(parsedSet),
      usedSample,
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
  });
}
