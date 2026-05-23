import { NextResponse } from "next/server";

import {
  authErrorResponse,
  getAuthenticatedUser,
} from "@/lib/request";
import { getProblemSetBySubmission, getSubmission } from "@/lib/store";
import { isGuardianLinkedToStudent } from "@/lib/users";

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
    const user = await getAuthenticatedUser(request);
    if (!user.profileComplete || !user.role) {
      return NextResponse.json(
        { error: "가입을 완료해 주세요." },
        { status: 403 },
      );
    }

    if (user.role === "student") {
      if (submission.userId !== user.id) {
        return NextResponse.json(
          { error: "제출 기록을 찾을 수 없습니다." },
          { status: 404 },
        );
      }
    } else {
      const linked = await isGuardianLinkedToStudent(
        user.id,
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
    problemSet,
  });
}
