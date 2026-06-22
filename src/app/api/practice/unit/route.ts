import { randomUUID } from "crypto";

import { NextResponse } from "next/server";

import { parseAnalyzeQualityMode } from "@/lib/analyze-mode";
import { resolveAzureDeploymentName } from "@/lib/azure";
import { authErrorResponse, resolveActorUserId } from "@/lib/request";
import { resolveUnitPracticeProblemSet } from "@/lib/problem-bank";
import { studyLog } from "@/lib/server-log";
import { saveProblemSet } from "@/lib/store";
import { generatedProblemSetSchema } from "@/lib/types";

export const runtime = "nodejs";
export const maxDuration = 120;

export async function POST(request: Request) {
  let userId = "anonymous";

  try {
    const actor = await resolveActorUserId(request, { write: true });
    userId = actor.actorUserId;
  } catch (error) {
    const authResponse = authErrorResponse(error);
    if (authResponse) {
      return authResponse;
    }
    return NextResponse.json(
      { error: "단원 연습 문제를 불러오지 못했습니다." },
      { status: 500 },
    );
  }

  try {
    const body = (await request.json()) as Record<string, unknown>;
    const unitId = String(body.unitId ?? "").trim();
    const qualityMode = parseAnalyzeQualityMode(body.qualityMode as string | null);
    const textDeploymentName =
      String(body.textDeploymentName ?? "").trim() ||
      resolveAzureDeploymentName(qualityMode) ||
      "";

    if (!unitId) {
      return NextResponse.json({ error: "unitId가 필요합니다." }, { status: 400 });
    }

    if (!textDeploymentName) {
      return NextResponse.json(
        { error: "Azure OpenAI 텍스트 배포가 설정되지 않았습니다." },
        { status: 500 },
      );
    }

    const problemSetId = randomUUID();
    studyLog("practice:unit", "POST start", { userId, unitId, problemSetId });

    const { problemSet, meta } = await resolveUnitPracticeProblemSet({
      userId,
      unitId,
      problemSetId,
      generateOptions: {
        deploymentName: textDeploymentName,
        mode: qualityMode,
      },
    });

    const parsedSet = generatedProblemSetSchema.parse(problemSet);
    await saveProblemSet(parsedSet);

    return NextResponse.json({
      unitId,
      problemSetId,
      problemSet: parsedSet,
      meta,
    });
  } catch (error) {
    studyLog("practice:unit", "failed", {
      error: error instanceof Error ? error.message : String(error),
    });
    return NextResponse.json(
      {
        error:
          error instanceof Error
            ? error.message
            : "단원 연습 문제를 불러오지 못했습니다.",
      },
      { status: 500 },
    );
  }
}
