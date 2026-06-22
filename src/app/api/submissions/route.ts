import { NextResponse } from "next/server";

import { GENERIC_INSIGHT_ERROR, logApiError } from "@/lib/api-errors";
import { authErrorResponse, resolveActorUserId } from "@/lib/request";
import { toSubmissionListItem } from "@/lib/submission-list";
import { getSubmissionsByUserId } from "@/lib/store";

export async function GET(request: Request) {
  let authUserId = "anonymous";

  try {
    const actor = await resolveActorUserId(request);
    authUserId = actor.authUserId;
    const submissions = await getSubmissionsByUserId(actor.actorUserId);

    return NextResponse.json({
      submissions: submissions.map(toSubmissionListItem),
    });
  } catch (error) {
    const authResponse = authErrorResponse(error);
    if (authResponse) {
      return authResponse;
    }

    const errorId = await logApiError({
      request,
      route: "/api/submissions",
      userId: authUserId,
      error,
    });

    return NextResponse.json(
      { error: GENERIC_INSIGHT_ERROR, errorId },
      { status: 500 },
    );
  }
}
