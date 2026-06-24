import { randomUUID } from "crypto";

import { NextResponse } from "next/server";

import { parseAnalyzeQualityMode } from "@/lib/analyze-mode";
import { buildTrainingSnapshot } from "@/lib/concept-training";
import { resolveAzureDeploymentName } from "@/lib/azure";
import { authErrorResponse, resolveActorUserId } from "@/lib/request";
import { resolveTrainingProblemSet } from "@/lib/problem-bank";
import {
  getPracticeMistakesForUser,
  getScannedProblemsForUser,
} from "@/lib/problem-bank-store";
import { studyLog } from "@/lib/server-log";
import { getAttempts, getProblemSet, getSubmissionsByUserId, saveProblemSet } from "@/lib/store";
import { findUserById } from "@/lib/users";
import { generatedProblemSetSchema } from "@/lib/types";

export const runtime = "nodejs";
export const maxDuration = 120;

export async function POST(request: Request) {
  let userId = "anonymous";
  let displayName: string | undefined;

  try {
    const actor = await resolveActorUserId(request, { write: true });
    userId = actor.actorUserId;
    displayName = actor.user.displayName;
  } catch (error) {
    const authResponse = authErrorResponse(error);
    if (authResponse) return authResponse;
    return NextResponse.json(
      { error: "복습 훈련을 시작하지 못했습니다." },
      { status: 500 },
    );
  }

  try {
    const body = (await request.json()) as Record<string, unknown>;
    const resumeSetId = String(body.setId ?? "").trim();
    const qualityMode = parseAnalyzeQualityMode(body.qualityMode as string | null);
    const textDeploymentName =
      String(body.textDeploymentName ?? "").trim() ||
      resolveAzureDeploymentName(qualityMode) ||
      "";

    const [attempts, submissions, mistakes, scanned] = await Promise.all([
      getAttempts(userId),
      getSubmissionsByUserId(userId, 30),
      getPracticeMistakesForUser(userId),
      getScannedProblemsForUser(userId),
    ]);

    const training = await buildTrainingSnapshot({
      userId,
      displayName,
      attempts,
      mistakes,
      scanned,
      submissions,
    });

    const resumeMeta = {
      bankCount: 5,
      setSize: 5,
      needsGeneration: false,
      generateCount: 0,
      newlyGeneratedCount: 0,
      bankSelectMs: 0,
    };

    if (resumeSetId) {
      const existing = await getProblemSet(resumeSetId);
      if (existing) {
        return NextResponse.json({
          problemSetId: existing.id,
          problemSet: existing,
          meta: resumeMeta,
          training,
        });
      }
    }

    if (training.activeSetId) {
      const existing = await getProblemSet(training.activeSetId);
      if (existing) {
        return NextResponse.json({
          problemSetId: existing.id,
          problemSet: existing,
          meta: resumeMeta,
          training,
        });
      }
    }

    if (!training.available || training.focusConcepts.length === 0) {
      return NextResponse.json(
        { error: "아직 훈련할 항목이 없습니다." },
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
    studyLog("practice:training", "POST start", {
      userId,
      problemSetId,
      focusConcepts: training.focusConcepts,
    });

    const user = await findUserById(userId);
    const { problemSet, meta } = await resolveTrainingProblemSet({
      userId,
      problemSetId,
      focusConcepts: training.focusConcepts,
      grade: user?.grade,
      generateOptions: {
        deploymentName: textDeploymentName,
        mode: qualityMode,
      },
    });

    const parsedSet = generatedProblemSetSchema.parse(problemSet);
    await saveProblemSet(parsedSet);

    const refreshedTraining = await buildTrainingSnapshot({
      userId,
      displayName: user?.displayName ?? displayName,
      attempts,
      mistakes,
      scanned,
      submissions,
    });

    return NextResponse.json({
      problemSetId,
      problemSet: parsedSet,
      meta,
      training: refreshedTraining,
    });
  } catch (error) {
    studyLog("practice:training", "failed", {
      error: error instanceof Error ? error.message : String(error),
    });
    return NextResponse.json(
      {
        error:
          error instanceof Error
            ? error.message
            : "복습 훈련을 시작하지 못했습니다.",
      },
      { status: 500 },
    );
  }
}
