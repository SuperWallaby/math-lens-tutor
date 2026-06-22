import { NextResponse } from "next/server";

import { authErrorResponse, resolveActorUserId } from "@/lib/request";
import { probeUnitPracticeAvailability } from "@/lib/problem-bank";
import { studyLog } from "@/lib/server-log";

export const runtime = "nodejs";

/** Bank 조회만 수행 — AI 생성 없이 needsGeneration 여부를 빠르게 반환합니다. */
export async function GET(request: Request) {
  let userId = "anonymous";

  try {
    const actor = await resolveActorUserId(request, { write: false });
    userId = actor.actorUserId;
  } catch (error) {
    const authResponse = authErrorResponse(error);
    if (authResponse) return authResponse;
    return NextResponse.json(
      { error: "단원 연습 가능 여부를 확인하지 못했습니다." },
      { status: 500 },
    );
  }

  try {
    const url = new URL(request.url);
    const unitId = String(url.searchParams.get("unitId") ?? "").trim();
    if (!unitId) {
      return NextResponse.json({ error: "unitId가 필요합니다." }, { status: 400 });
    }

    const preview = await probeUnitPracticeAvailability({ userId, unitId });
    studyLog("practice:unit", "preview", { userId, ...preview });

    return NextResponse.json({ preview });
  } catch (error) {
    studyLog("practice:unit", "preview failed", {
      error: error instanceof Error ? error.message : String(error),
    });
    return NextResponse.json(
      {
        error:
          error instanceof Error
            ? error.message
            : "단원 연습 가능 여부를 확인하지 못했습니다.",
      },
      { status: 500 },
    );
  }
}
