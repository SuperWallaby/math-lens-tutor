import { NextResponse } from "next/server";

import { GENERIC_INSIGHT_ERROR, logApiError } from "@/lib/api-errors";
import { buildTeacherClassOverview } from "@/lib/learning-profile";
import { authErrorResponse, requireAuthenticatedUser } from "@/lib/request";

export async function GET(request: Request) {
  let authUserId = "anonymous";

  try {
    const user = await requireAuthenticatedUser(request);
    authUserId = user.id;

    if (user.role !== "teacher") {
      return NextResponse.json(
        { error: "교사 계정만 이용할 수 있습니다." },
        { status: 403 },
      );
    }

    const overview = await buildTeacherClassOverview(user);
    return NextResponse.json({ overview });
  } catch (error) {
    const authResponse = authErrorResponse(error);
    if (authResponse) {
      return authResponse;
    }

    const errorId = await logApiError({
      request,
      route: "/api/teacher/overview",
      userId: authUserId,
      error,
    });

    return NextResponse.json(
      { error: GENERIC_INSIGHT_ERROR, errorId },
      { status: 500 },
    );
  }
}
