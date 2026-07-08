import { NextResponse } from "next/server";

import { GENERIC_INSIGHT_ERROR, logApiError } from "@/lib/api-errors";
import { getLearningProfileForUser } from "@/lib/learning-profile-snapshot";
import { toLearningProfileSummary } from "@/lib/learning-profile-summary";
import { authErrorResponse, resolveActorUserId } from "@/lib/request";
import { prewarmTrainingFeedIfNeeded } from "@/lib/training-feed";
import { findUserById } from "@/lib/users";

const SUMMARY_CACHE_SEC = 90;

export async function GET(request: Request) {
  let authUserId = "anonymous";

  try {
    const actor = await resolveActorUserId(request);
    authUserId = actor.authUserId;
    const student = await findUserById(actor.actorUserId);
    const grade = student?.grade ?? actor.user.grade ?? "중1";
    const profile = await getLearningProfileForUser(actor.actorUserId, grade);

    const url = new URL(request.url);
    const scope = url.searchParams.get("scope")?.trim().toLowerCase();
    const isSummary = scope === "summary";

    if (isSummary) {
      void prewarmTrainingFeedIfNeeded(actor.actorUserId);
    }

    const body = isSummary
      ? { profile: toLearningProfileSummary(profile) }
      : { profile };

    return NextResponse.json(body, {
      headers: isSummary
        ? { "Cache-Control": `private, max-age=${SUMMARY_CACHE_SEC}` }
        : undefined,
    });
  } catch (error) {
    const authResponse = authErrorResponse(error);
    if (authResponse) {
      return authResponse;
    }

    const errorId = await logApiError({
      request,
      route: "/api/learning/profile",
      userId: authUserId,
      error,
    });

    return NextResponse.json(
      { error: GENERIC_INSIGHT_ERROR, errorId },
      { status: 500 },
    );
  }
}
