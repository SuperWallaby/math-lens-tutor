import { NextResponse } from "next/server";
import { getProblemSetBySubmission, getSubmission } from "@/lib/store";

export async function GET(
  _request: Request,
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

  const problemSet = await getProblemSetBySubmission(submission.id);

  return NextResponse.json({
    submission,
    problemSet,
  });
}
