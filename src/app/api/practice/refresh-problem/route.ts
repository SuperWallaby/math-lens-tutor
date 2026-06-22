import { NextResponse } from "next/server";

import { parseAnalyzeQualityMode } from "@/lib/analyze-mode";
import { resolveAzureDeploymentName } from "@/lib/azure";
import { authErrorResponse, resolveActorUserId } from "@/lib/request";
import { replacePracticeProblem } from "@/lib/problem-bank";
import { studyLog } from "@/lib/server-log";
import { getProblemSet, updateProblemSet } from "@/lib/store";
import { findUserById } from "@/lib/users";

export const runtime = "nodejs";
export const maxDuration = 120;

export async function POST(request: Request) {
  let userId = "anonymous";

  try {
    const actor = await resolveActorUserId(request, { write: true });
    userId = actor.actorUserId;
  } catch (error) {
    const authResponse = authErrorResponse(error);
    if (authResponse) return authResponse;
    return NextResponse.json(
      { error: "문제를 교체하지 못했습니다." },
      { status: 500 },
    );
  }

  try {
    const body = (await request.json()) as Record<string, unknown>;
    const setId = String(body.setId ?? "").trim();
    const problemId = String(body.problemId ?? "").trim();
    const harder = body.harder === true;
    const qualityMode = parseAnalyzeQualityMode(body.qualityMode as string | null);
    const textDeploymentName =
      String(body.textDeploymentName ?? "").trim() ||
      resolveAzureDeploymentName(qualityMode) ||
      "";

    if (!setId || !problemId) {
      return NextResponse.json(
        { error: "setId와 problemId가 필요합니다." },
        { status: 400 },
      );
    }

    if (!textDeploymentName) {
      return NextResponse.json(
        { error: "Azure OpenAI 텍스트 배포가 설정되지 않았습니다." },
        { status: 500 },
      );
    }

    const problemSet = await getProblemSet(setId);
    if (!problemSet) {
      return NextResponse.json(
        { error: "문제 세트를 찾을 수 없습니다." },
        { status: 404 },
      );
    }

    studyLog("practice:refresh-problem", "POST start", {
      userId,
      setId,
      problemId,
      harder,
    });

    const user = await findUserById(userId);
    const result = await replacePracticeProblem({
      userId,
      problemSet,
      problemId,
      harder,
      grade: user?.grade,
      generateOptions: {
        deploymentName: textDeploymentName,
        mode: qualityMode,
      },
    });

    await updateProblemSet(result.problemSet);

    return NextResponse.json({
      problemSet: result.problemSet,
      problem: result.problem,
    });
  } catch (error) {
    studyLog("practice:refresh-problem", "failed", {
      error: error instanceof Error ? error.message : String(error),
    });
    return NextResponse.json(
      {
        error:
          error instanceof Error
            ? error.message
            : "문제를 교체하지 못했습니다.",
      },
      { status: 500 },
    );
  }
}
