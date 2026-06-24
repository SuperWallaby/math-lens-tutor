import { NextResponse } from "next/server";
import { withRequestDb } from "@/lib/db-variant";
import { getProblemSet } from "@/lib/store";

export async function GET(
  request: Request,
  { params }: { params: Promise<{ id: string }> },
) {
  return withRequestDb(request, async () => {
    const { id } = await params;
    const problemSet = await getProblemSet(id);

    if (!problemSet) {
      return NextResponse.json(
        { error: "문제 세트를 찾을 수 없습니다." },
        { status: 404 },
      );
    }

    return NextResponse.json({ problemSet });
  });
}
