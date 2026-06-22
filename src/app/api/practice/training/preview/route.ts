import { NextResponse } from "next/server";

import { buildTrainingSnapshot } from "@/lib/concept-training";
import { authErrorResponse, resolveActorUserId } from "@/lib/request";
import { probeTrainingPracticeAvailability } from "@/lib/problem-bank";
import {
  getPracticeMistakesForUser,
  getScannedProblemsForUser,
} from "@/lib/problem-bank-store";
import { studyLog } from "@/lib/server-log";
import { getAttempts, getSubmissionsByUserId } from "@/lib/store";
import { findUserById } from "@/lib/users";

export const runtime = "nodejs";

/** Bank 조회만 수행 — 복습 훈련에서 AI 생성 필요 여부를 빠르게 반환합니다. */
export async function GET(request: Request) {
  let userId = "anonymous";

  try {
    const actor = await resolveActorUserId(request, { write: false });
    userId = actor.actorUserId;
  } catch (error) {
    const authResponse = authErrorResponse(error);
    if (authResponse) return authResponse;
    return NextResponse.json(
      { error: "복습 훈련 가능 여부를 확인하지 못했습니다." },
      { status: 500 },
    );
  }

  try {
    const [attempts, submissions, mistakes, scanned, user] = await Promise.all([
      getAttempts(userId),
      getSubmissionsByUserId(userId, 30),
      getPracticeMistakesForUser(userId),
      getScannedProblemsForUser(userId),
      findUserById(userId),
    ]);

    const training = await buildTrainingSnapshot({
      userId,
      attempts,
      mistakes,
      scanned,
      submissions,
    });

    if (!training.available || training.focusConcepts.length === 0) {
      return NextResponse.json(
        { error: "아직 훈련할 항목이 없습니다." },
        { status: 400 },
      );
    }

    const preview = await probeTrainingPracticeAvailability({
      userId,
      focusConcepts: training.focusConcepts,
      grade: user?.grade,
    });

    studyLog("practice:training", "preview", { userId, ...preview });

    return NextResponse.json({ preview, training });
  } catch (error) {
    studyLog("practice:training", "preview failed", {
      error: error instanceof Error ? error.message : String(error),
    });
    return NextResponse.json(
      {
        error:
          error instanceof Error
            ? error.message
            : "복습 훈련 가능 여부를 확인하지 못했습니다.",
      },
      { status: 500 },
    );
  }
}
