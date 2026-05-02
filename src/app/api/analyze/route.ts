import { randomUUID } from "crypto";
import { NextResponse } from "next/server";
import { GENERIC_ANALYZE_ERROR, logApiError } from "@/lib/api-errors";
import { analyzeSolutionImage, generateSimilarProblems } from "@/lib/azure";
import { getRequestUserId } from "@/lib/request";
import {
  saveProblemSet,
  saveSubmission,
  uploadSolutionImage,
} from "@/lib/store";
import type { SolutionSubmission } from "@/lib/types";

export const runtime = "nodejs";

export async function POST(request: Request) {
  const userId = getRequestUserId(request);

  try {
    const formData = (await request.formData()) as unknown as {
      get(name: string): FormDataEntryValue | null;
    };
    const file = formData.get("image");

    if (!(file instanceof File) || file.size === 0) {
      return NextResponse.json(
        { error: "풀이 사진 파일을 첨부해 주세요." },
        { status: 400 },
      );
    }

    const submissionId = randomUUID();
    const [imageUrl, analysis] = await Promise.all([
      uploadSolutionImage(file, userId),
      analyzeSolutionImage(file),
    ]);

    const submission: SolutionSubmission = {
      id: submissionId,
      userId,
      imageUrl,
      imageName: file.name,
      createdAt: new Date().toISOString(),
      analysis,
    };

    const problemSet = await generateSimilarProblems(analysis, submissionId);

    await saveSubmission(submission);
    await saveProblemSet(problemSet);

    return NextResponse.json({
      submissionId: submission.id,
      problemSetId: problemSet.id,
      submission,
      problemSet,
    });
  } catch (error) {
    const errorId = await logApiError({
      request,
      route: "/api/analyze",
      userId,
      error,
    });

    return NextResponse.json(
      { error: GENERIC_ANALYZE_ERROR, errorId },
      { status: 500 },
    );
  }
}
