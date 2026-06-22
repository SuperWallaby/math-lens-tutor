import { randomUUID } from "crypto";
import { NextResponse } from "next/server";
import { GENERIC_SUBMIT_ERROR, logApiError } from "@/lib/api-errors";
import {
  generatePracticeWrongAnswerFeedback,
  resolveAzureDeploymentName,
} from "@/lib/azure";
import { authErrorResponse, resolveActorUserId } from "@/lib/request";
import { recordPracticeAttempt } from "@/lib/problem-bank";
import { recordTrainingFeedActivity } from "@/lib/training-feed";
import { studyLog } from "@/lib/server-log";
import { getProblemSet, saveAttempt } from "@/lib/store";
import type { GeneratedProblem, ProblemAttempt } from "@/lib/types";
import {
  formatAnswerForDisplay,
  normalizeAnswerForGrade,
  stripMathDelimiters,
} from "@/lib/answer-normalize";

export const runtime = "nodejs";
export const maxDuration = 60;

type GeneratedChoice = NonNullable<GeneratedProblem["choices"]>[number];

/** LLM 이 객관식에 번호(1~5)만 넣는 경우가 있어 라벨과 비교되며 전부 오답 처리되는 것을 막음 */
function expectedAnswerForProblem(problem: GeneratedProblem): string {
  const raw = stripMathDelimiters(problem.correctAnswer.trim());
  const choices = problem.choices ?? [];
  const byId = choices.find((c) => c.id === raw || c.id === problem.correctAnswer.trim());
  if (byId) {
    return formatAnswerForDisplay(byId.label);
  }
  const byLabel = choices.find(
    (c) => normalizeAnswerForGrade(c.label) === normalizeAnswerForGrade(raw),
  );
  if (byLabel) {
    return formatAnswerForDisplay(byLabel.label);
  }
  return formatAnswerForDisplay(raw);
}

export async function POST(request: Request) {
  let authUserId = "anonymous";
  let actor;

  try {
    actor = await resolveActorUserId(request, { write: true });
    authUserId = actor.authUserId;
  } catch (error) {
    const authResponse = authErrorResponse(error);
    if (authResponse) {
      return authResponse;
    }
    return NextResponse.json(
      { error: GENERIC_SUBMIT_ERROR },
      { status: 500 },
    );
  }

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
    const normalizedSubmitted = normalizeAnswerForGrade(submittedAnswer);
    const normalizedExpected = normalizeAnswerForGrade(expected);
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

    let feedbackText = "정답입니다.";
    if (!isCorrect) {
      const deploymentName = resolveAzureDeploymentName("fast") ?? "";
      feedbackText = await generatePracticeWrongAnswerFeedback({
        problem,
        submittedAnswer,
        expectedAnswer: expected,
        grade: actor.user.grade,
        deploymentName,
      });
    }

    const attempt: ProblemAttempt = {
      id: randomUUID(),
      userId: actor.actorUserId,
      setId: body.setId,
      problemId: body.problemId,
      answer: submittedAnswer,
      isCorrect,
      feedback: feedbackText,
      createdAt: new Date().toISOString(),
    };

    const relearnedConcepts = await recordPracticeAttempt({
      attempt,
      problem,
      expectedAnswer: expected,
    });

    if (isCorrect && relearnedConcepts.length > 0) {
      attempt.feedback = `${attempt.feedback} [재학습 성공됨: ${relearnedConcepts.join(", ")}]`;
    }

    await saveAttempt(attempt);

    void recordTrainingFeedActivity({
      userId: actor.actorUserId,
      conceptTags: problem.conceptTags?.length
        ? problem.conceptTags
        : [problem.title],
      difficulty: problem.difficulty ?? "medium",
      isCorrect,
    }).catch(() => {});

    return NextResponse.json({
      ...attempt,
      relearnedConcepts,
    });
  } catch (error) {
    const errorId = await logApiError({
      request,
      route: "/api/attempts",
      userId: authUserId,
      error,
    });

    return NextResponse.json(
      { error: GENERIC_SUBMIT_ERROR, errorId },
      { status: 500 },
    );
  }
}
