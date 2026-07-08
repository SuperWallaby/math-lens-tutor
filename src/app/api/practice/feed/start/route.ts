import { NextResponse } from "next/server";

import { stripProblemSetForClient } from "@/lib/client-problem";
import { authErrorResponse, resolveActorUserId } from "@/lib/request";
import { startFeedItemPractice } from "@/lib/training-feed";

export const runtime = "nodejs";

export async function POST(request: Request) {
  try {
    const actor = await resolveActorUserId(request, { write: true });
    const body = (await request.json()) as {
      feedItemId?: string;
      bankItemId?: string;
    };

    const feedItemId = String(body.feedItemId ?? "").trim();
    const bankItemId = String(body.bankItemId ?? "").trim();
    if (!feedItemId && !bankItemId) {
      return NextResponse.json(
        { error: "피드 항목 ID가 필요합니다." },
        { status: 400 },
      );
    }

    const { problemSet, feedItem } = await startFeedItemPractice({
      userId: actor.actorUserId,
      feedItemId: feedItemId || undefined,
      bankItemId: bankItemId || undefined,
    });

    return NextResponse.json({
      problemSetId: problemSet.id,
      problemSet: stripProblemSetForClient(problemSet),
      feedItem,
      meta: {
        bankCount: 1,
        setSize: 1,
        needsGeneration: false,
        generateCount: 0,
        newlyGeneratedCount: 0,
        bankSelectMs: 0,
      },
    });
  } catch (error) {
    const authResponse = authErrorResponse(error);
    if (authResponse) return authResponse;
    return NextResponse.json(
      {
        error:
          error instanceof Error
            ? error.message
            : "피드 문제를 시작하지 못했습니다.",
      },
      { status: 500 },
    );
  }
}
