import { randomUUID } from "crypto";
import { NextResponse } from "next/server";
import { GENERIC_SUBMIT_ERROR, logApiError } from "@/lib/api-errors";
import { getRequestUserId } from "@/lib/request";
import { studyLog } from "@/lib/server-log";
import { getProblemSet, saveAttempt } from "@/lib/store";
import type { GeneratedProblem, ProblemAttempt } from "@/lib/types";

type GeneratedChoice = NonNullable<GeneratedProblem["choices"]>[number];

function normalizeAnswer(answer: string) {
  return answer
    .replace(/\s+/g, "")
    .replace(/\u2212/g, "-")
    .replace(/，/g, ",")
    .toLowerCase();
}

/** LLM 이 객관식에 번호(1~5)만 넣는 경우가 있어 라벨과 비교되며 전부 오답 처리되는 것을 막음 */
function expectedAnswerForProblem(problem: GeneratedProblem): string {
  const raw = problem.correctAnswer.trim();
  const choices = problem.choices ?? [];
  const byId = choices.find((c) => c.id === raw);
  if (byId) {
    return byId.label;
  }
  const byLabel = choices.find(
    (c) => normalizeAnswer(c.label) === normalizeAnswer(raw),
  );
  if (byLabel) {
    return byLabel.label;
  }
  return raw;
}

export async function POST(request: Request) {
  const userId = getRequestUserId(request);

  try {
    const body = (await request.json()) as {
      setId?: string;
      problemId?: string;
      answer?: string;
    };

    if (!body.setId || !body.problemId || !body.answer) {
      return NextResponse.json(
        { error: "문제 세트, 문제, 답안을 모두 보내 주세요." },
        { status: 400 },
      );
    }

    const problemSet = await getProblemSet(body.setId);
    const problem = problemSet?.problems.find(
      (item: GeneratedProblem) => item.id === body.problemId,
    );

    if (!problem) {
      return NextResponse.json(
        { error: "문제를 찾을 수 없습니다." },
        { status: 404 },
      );
    }

    const chosenChoice = problem.choices?.find(
      (choice: GeneratedChoice) =>
        choice.id === body.answer || choice.label === body.answer,
    );
    const submittedAnswer = chosenChoice?.label ?? body.answer;
    const expected = expectedAnswerForProblem(problem);
    const normalizedSubmitted = normalizeAnswer(submittedAnswer);
    const normalizedExpected = normalizeAnswer(expected);
    const isCorrect = normalizedSubmitted === normalizedExpected;

    studyLog("attempts", "grade", {
      setId: body.setId,
      problemId: body.problemId,
      problemType: problem.type,
      rawCorrectAnswer: problem.correctAnswer,
      expectedAfterResolve: expected,
      bodyAnswer: body.answer,
      submittedAnswer,
      normalizedSubmitted,
      normalizedExpected,
      isCorrect,
    });

    const attempt: ProblemAttempt = {
      id: randomUUID(),
      userId,
      setId: body.setId,
      problemId: body.problemId,
      answer: submittedAnswer,
      isCorrect,
      feedback: isCorrect
        ? "정답입니다. 같은 풀이 전략을 다음 문제에도 적용해 보세요."
        : `오답입니다. 정답은 ${expected}입니다. ${problem.explanation}`,
      createdAt: new Date().toISOString(),
    };

    await saveAttempt(attempt);

    return NextResponse.json(attempt);
  } catch (error) {
    const errorId = await logApiError({
      request,
      route: "/api/attempts",
      userId,
      error,
    });

    return NextResponse.json(
      { error: GENERIC_SUBMIT_ERROR, errorId },
      { status: 500 },
    );
  }
}
