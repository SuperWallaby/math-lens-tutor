import { NextResponse } from "next/server";
import { GENERIC_INSIGHT_ERROR, logApiError } from "@/lib/api-errors";
import { getRequestUserId } from "@/lib/request";
import { getLearningInsight } from "@/lib/store";

export async function GET(request: Request) {
  const userId = getRequestUserId(request);

  try {
    const insight = await getLearningInsight(userId);

    return NextResponse.json({ insight });
  } catch (error) {
    const errorId = await logApiError({
      request,
      route: "/api/insights",
      userId,
      error,
    });

    return NextResponse.json(
      { error: GENERIC_INSIGHT_ERROR, errorId },
      { status: 500 },
    );
  }
}
