import { randomUUID } from "crypto";

import { NextResponse } from "next/server";

import { parseAnalyzeQualityMode } from "@/lib/analyze-mode";
import { resolveAzureDeploymentName } from "@/lib/azure";
import { authErrorResponse, resolveActorUserId } from "@/lib/request";
import {
  resolvePracticeProblemSet,
  resolveUnitPracticeProblemSet,
} from "@/lib/problem-bank";
import { studyLog } from "@/lib/server-log";
import { getSubmission, saveProblemSet } from "@/lib/store";
import { findUserById } from "@/lib/users";
import { generatedProblemSetSchema } from "@/lib/types";

export const runtime = "nodejs";
export const maxDuration = 120;

const UNIT_SUBMISSION_PREFIX = "unit:";

export async function POST(request: Request) {
  let userId = "anonymous";

  try {
    const actor = await resolveActorUserId(request, { write: true });
    userId = actor.actorUserId;
  } catch (error) {
    const authResponse = authErrorResponse(error);
    if (authResponse) return authResponse;
    return NextResponse.json(
      { error: "새 연습 문제를 불러오지 못했습니다." },
      { status: 500 },
    );
  }

  try {
    const body = (await request.json()) as Record<string, unknown>;
    const submissionId = String(body.submissionId ?? "").trim();
    const previousSetId = String(body.previousSetId ?? "").trim();
    const difficultyBias =
      body.difficultyBias === "harder" ? ("harder" as const) : ("same" as const);
    const qualityMode = parseAnalyzeQualityMode(body.qualityMode as string | null);
    const textDeploymentName =
      String(body.textDeploymentName ?? "").trim() ||
      resolveAzureDeploymentName(qualityMode) ||
      "";

    if (!submissionId) {
      return NextResponse.json(
        { error: "submissionId가 필요합니다." },
        { status: 400 },
      );
    }

    if (!textDeploymentName) {
      return NextResponse.json(
        { error: "Azure OpenAI 텍스트 배포가 설정되지 않았습니다." },
        { status: 500 },
      );
    }

    const problemSetId = randomUUID();
    studyLog("practice:retry", "POST start", {
      userId,
      submissionId,
      previousSetId,
      problemSetId,
    });

    const generateOptions = {
      deploymentName: textDeploymentName,
      mode: qualityMode,
    };

    let problemSet;
    if (submissionId.startsWith(UNIT_SUBMISSION_PREFIX)) {
      const unitId = submissionId.slice(UNIT_SUBMISSION_PREFIX.length);
      if (!unitId) {
        return NextResponse.json({ error: "unitId가 필요합니다." }, { status: 400 });
      }
      problemSet = await resolveUnitPracticeProblemSet({
        userId,
        unitId,
        problemSetId,
        generateOptions,
        difficultyBias,
      });
    } else {
      const submission = await getSubmission(submissionId);
      if (!submission) {
        return NextResponse.json(
          { error: "원본 분석을 찾을 수 없습니다." },
          { status: 404 },
        );
      }
      const user = await findUserById(userId);
      problemSet = await resolvePracticeProblemSet({
        userId,
        analysis: submission.analysis,
        submissionId,
        problemSetId,
        grade: user?.grade,
        generateOptions: {
          ...generateOptions,
          fromVisionOcrOnly: false,
        },
        difficultyBias,
      });
    }

    const parsedSet = generatedProblemSetSchema.parse(problemSet);
    await saveProblemSet(parsedSet);

    return NextResponse.json({
      submissionId,
      problemSetId,
      problemSet: parsedSet,
    });
  } catch (error) {
    studyLog("practice:retry", "failed", {
      error: error instanceof Error ? error.message : String(error),
    });
    return NextResponse.json(
      {
        error:
          error instanceof Error
            ? error.message
            : "새 연습 문제를 불러오지 못했습니다.",
      },
      { status: 500 },
    );
  }
}
