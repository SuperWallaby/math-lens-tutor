import { NextResponse } from "next/server";
import { GENERIC_INSIGHT_ERROR, logApiError } from "@/lib/api-errors";
import { authErrorResponse, resolveActorUserId } from "@/lib/request";
import { getLearningInsight } from "@/lib/store";

export async function GET(request: Request) {
  let authUserId = "anonymous";

  try {
    const actor = await resolveActorUserId(request);
    authUserId = actor.authUserId;
    const insight = await getLearningInsight(actor.actorUserId);

    return NextResponse.json({ insight });
  } catch (error) {
    const authResponse = authErrorResponse(error);
    if (authResponse) {
      return authResponse;
    }

    const errorId = await logApiError({
      request,
      route: "/api/insights",
      userId: authUserId,
      error,
    });

    return NextResponse.json(
      { error: GENERIC_INSIGHT_ERROR, errorId },
      { status: 500 },
    );
  }
}
