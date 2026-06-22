import { NextResponse } from "next/server";

import { authErrorResponse, resolveActorUserId } from "@/lib/request";
import { getTrainingFeedResponse } from "@/lib/training-feed";

export const runtime = "nodejs";

export async function GET(request: Request) {
  try {
    const actor = await resolveActorUserId(request);
    const feed = await getTrainingFeedResponse(actor.actorUserId);
    return NextResponse.json(feed);
  } catch (error) {
    const authResponse = authErrorResponse(error);
    if (authResponse) return authResponse;
    return NextResponse.json(
      { error: "훈련 피드를 불러오지 못했습니다." },
      { status: 500 },
    );
  }
}
