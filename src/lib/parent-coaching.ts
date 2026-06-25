import { formatSubmissionListTitle } from "./submission-list";
import { truncateMathSafe } from "./truncate-math-safe";
import type {
  ParentCoachingCard,
  ParentWrongExplainItem,
  PracticeMistakeRecord,
  SolutionAnalysis,
  SolutionSubmission,
} from "./types";

function truncate(text: string, max: number): string {
  return truncateMathSafe(text, max, { preserveBreaks: false });
}

export function truncatePreserveBreaks(text: string, max: number): string {
  return truncateMathSafe(text, max, { preserveBreaks: true });
}

/** STEP 7 — 모범 풀이 7단계 중 핵심 채점 포인트 (없으면 recommendedFocus / errorSummary) */
export function pickGradingPoint(analysis: SolutionAnalysis): string {
  const steps = (analysis.referenceSolutionSteps ?? []).filter(Boolean);
  if (steps.length >= 7) return truncate(steps[6], 140);
  if (steps.length > 0) return truncate(steps[steps.length - 1], 140);

  const focus = analysis.recommendedFocus.find((s) => s.trim());
  if (focus) return truncate(focus, 140);

  return truncate(analysis.errorSummary, 140);
}

function submissionProblemLabel(submission: SolutionSubmission): string {
  const name = submission.imageName?.trim();
  if (name) {
    const num = name.match(/(\d+)\s*번/);
    if (num) return `${num[1]}번`;
  }
  return truncate(
    formatSubmissionListTitle(submission),
    28,
  );
}

function buildEasyExplainFromAnalysis(analysis: SolutionAnalysis): string {
  const parts = [
    analysis.errorSummary.trim(),
    ...(analysis.referenceSolutionSteps ?? []).slice(0, 2).map((s) => s.trim()),
  ].filter(Boolean);
  return truncatePreserveBreaks(parts.join("\n\n"), 480);
}

function buildParentScript(
  gradingPoint: string,
  concept: string,
): string {
  return `「${concept}」에서 "${gradingPoint}" — 아이에게 왜 그렇게 생각했는지, 한 번 설명해 달라고 해보세요.`;
}

function buildCoachingQuestion(
  problemLabel: string | null,
  gradingPoint: string,
  concept: string,
): string {
  if (problemLabel) {
    return `오늘 자녀에게: "${problemLabel}에서 ${gradingPoint} — 왜 그렇게 생각했어?"`;
  }
  return `오늘 자녀에게: "「${concept}」 문제에서 ${gradingPoint}가 맞는지 설명해 줄래?"`;
}

function isWrongSubmission(submission: SolutionSubmission): boolean {
  const student = submission.analysis.extractedStudentAnswer.trim();
  const correct = submission.analysis.inferredCorrectAnswer.trim();
  if (!student || !correct) return true;
  return student !== correct;
}

export function buildParentCoachingCard(params: {
  submissions: SolutionSubmission[];
  mistakes: PracticeMistakeRecord[];
}): ParentCoachingCard | null {
  const latestWrongSubmission = params.submissions.find(isWrongSubmission);
  if (latestWrongSubmission) {
    const analysis = latestWrongSubmission.analysis;
    const concept =
      analysis.weakConcepts[0]?.trim() ||
      analysis.recommendedFocus[0]?.trim() ||
      "최근 오답";
    const gradingPoint = pickGradingPoint(analysis);
    const problemLabel = submissionProblemLabel(latestWrongSubmission);

    return {
      label: "오늘의 부모 코칭",
      question: buildCoachingQuestion(problemLabel, gradingPoint, concept),
      gradingPoint,
      context: truncatePreserveBreaks(analysis.problemText, 160),
      sourceType: "submission",
      sourceId: latestWrongSubmission.id,
      problemLabel,
    };
  }

  const latestMistake = params.mistakes.find((m) => !m.resolvedAt);
  if (latestMistake) {
    const concept = latestMistake.conceptPrimary || "연습 오답";
    const gradingPoint = truncate(
      latestMistake.feedback || `${concept} 개념 확인`,
      140,
    );
    return {
      label: "오늘의 부모 코칭",
      question: buildCoachingQuestion(null, gradingPoint, concept),
      gradingPoint,
      context: `연습에서 ${concept} 관련 오답이 있었어요.`,
      sourceType: "practice",
      sourceId: latestMistake.id,
      problemLabel: null,
    };
  }

  return null;
}

export function buildParentWrongExplains(params: {
  submissions: SolutionSubmission[];
  mistakes: PracticeMistakeRecord[];
  limit?: number;
}): ParentWrongExplainItem[] {
  const limit = params.limit ?? 5;
  const items: ParentWrongExplainItem[] = [];

  for (const submission of params.submissions) {
    if (!isWrongSubmission(submission)) continue;
    const analysis = submission.analysis;
    const concept =
      analysis.weakConcepts[0]?.trim() ||
      analysis.recommendedFocus[0]?.trim() ||
      "오답 분석";
    const gradingPoint = pickGradingPoint(analysis);
    items.push({
      id: `sub-${submission.id}`,
      sourceType: "submission",
      sourceId: submission.id,
      title: formatSubmissionListTitle(submission),
      concept,
      easyExplain: buildEasyExplainFromAnalysis(analysis),
      parentScript: buildParentScript(gradingPoint, concept),
      problemSetId: null,
      imageUrl: submission.imageUrl,
      createdAt: submission.createdAt,
    });
    if (items.length >= limit) return items;
  }

  for (const mistake of params.mistakes) {
    if (mistake.resolvedAt) continue;
    const concept = mistake.conceptPrimary || "연습 오답";
    const gradingPoint = truncate(
      mistake.feedback || `${concept} 확인`,
      140,
    );
    items.push({
      id: `prac-${mistake.id}`,
      sourceType: "practice",
      sourceId: mistake.id,
      title: `${concept} 연습`,
      concept,
      easyExplain: truncate(
        [
          `학생 답: ${mistake.answer}`,
          `정답: ${mistake.expectedAnswer}`,
          mistake.feedback,
        ]
          .filter(Boolean)
          .join("\n"),
        480,
      ),
      parentScript: buildParentScript(gradingPoint, concept),
      problemSetId: mistake.setId,
      imageUrl: null,
      createdAt: mistake.createdAt,
    });
    if (items.length >= limit) return items;
  }

  return items;
}
