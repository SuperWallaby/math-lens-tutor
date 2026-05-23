import { NextResponse } from "next/server";

import { GENERIC_INSIGHT_ERROR, logApiError } from "@/lib/api-errors";
import { buildLearningProfile } from "@/lib/learning-profile";
import { authErrorResponse, resolveActorUserId } from "@/lib/request";
import { findUserById } from "@/lib/users";

export async function GET(request: Request) {
  let authUserId = "anonymous";

  try {
    const actor = await resolveActorUserId(request);
    authUserId = actor.authUserId;
    const student = await findUserById(actor.actorUserId);
    const profile = await buildLearningProfile(
      actor.actorUserId,
      student?.grade ?? "중1",
    );

    return NextResponse.json({ profile });
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
