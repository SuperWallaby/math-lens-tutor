import { NextResponse } from "next/server";

import { stripProblemSetForClient } from "@/lib/client-problem";
import {
  authErrorResponse,
  resolveActorUserId,
} from "@/lib/request";
import { getProblemSetBySubmission, getSubmission } from "@/lib/store";

export async function GET(
  request: Request,
  { params }: { params: Promise<{ id: string }> },
) {
  const { id } = await params;
  const submission = await getSubmission(id);

  if (!submission) {
    return NextResponse.json(
      { error: "제출 기록을 찾을 수 없습니다." },
      { status: 404 },
    );
  }

  try {
    const actor = await resolveActorUserId(request);

    if (actor.isGuest || actor.role === "student") {
      if (submission.userId !== actor.actorUserId) {
        return NextResponse.json(
          { error: "제출 기록을 찾을 수 없습니다." },
          { status: 404 },
        );
      }
    } else {
      const { isGuardianLinkedToStudent } = await import("@/lib/users");
      const linked = await isGuardianLinkedToStudent(
        actor.authUserId,
        submission.userId,
      );
      if (!linked) {
        return NextResponse.json(
          { error: "연결되지 않은 학생의 기록입니다." },
          { status: 403 },
        );
      }
    }
  } catch (error) {
    const authResponse = authErrorResponse(error);
    if (authResponse) {
      return authResponse;
    }
    return NextResponse.json(
      { error: "제출 기록을 불러오지 못했습니다." },
      { status: 500 },
    );
  }

  const problemSet = await getProblemSetBySubmission(submission.id);

  return NextResponse.json({
    submission,
    problemSet: problemSet ? stripProblemSetForClient(problemSet) : null,
  });
}
