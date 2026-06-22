import { getLatestProblemSetWithSubmissionPrefix } from "./store";
import type {
  PracticeMistakeRecord,
  ProblemAttempt,
  ScannedProblemRecord,
  SolutionSubmission,
  TrainingFocusItem,
  TrainingSnapshot,
} from "./types";

export const TRAINING_SUBMISSION_PREFIX = "training:";

export function trainingSubmissionId(userId: string): string {
  return `${TRAINING_SUBMISSION_PREFIX}${userId}`;
}

function conceptKey(concept: string): string {
  return concept.trim().toLowerCase();
}

export function conceptsOverlap(a: string, b: string): boolean {
  const x = conceptKey(a);
  const y = conceptKey(b);
  if (!x || !y) return false;
  return x === y || x.includes(y) || y.includes(x);
}

type ConceptRow = {
  display: string;
  missScore: number;
  relearned: number;
};

function rememberConcept(
  map: Map<string, ConceptRow>,
  concept: string,
): ConceptRow {
  const key = conceptKey(concept);
  const trimmed = concept.trim();
  const existing = map.get(key);
  if (existing) return existing;
  const row: ConceptRow = {
    display: trimmed,
    missScore: 0,
    relearned: 0,
  };
  map.set(key, row);
  return row;
}

export function buildTrainingFocusItems(params: {
  mistakes: PracticeMistakeRecord[];
  scanned: ScannedProblemRecord[];
  submissions: SolutionSubmission[];
}): TrainingFocusItem[] {
  const rows = new Map<string, ConceptRow>();

  for (const mistake of params.mistakes) {
    const concepts = [
      mistake.conceptPrimary,
      ...mistake.conceptTags,
    ].filter((value) => value.trim());

    for (const concept of concepts) {
      const row = rememberConcept(rows, concept);
      if (mistake.resolvedAt) {
        row.relearned += 1;
      } else {
        row.missScore += 1;
      }
    }
  }

  for (const record of params.scanned) {
    for (const concept of [...record.weakConcepts, ...record.conceptTags]) {
      if (!concept.trim()) continue;
      rememberConcept(rows, concept).missScore += 1;
    }
  }

  for (const submission of params.submissions.slice(0, 12)) {
    for (const concept of submission.analysis.weakConcepts) {
      if (!concept.trim()) continue;
      rememberConcept(rows, concept).missScore += 1;
    }
  }

  return [...rows.values()]
    .map((row) => {
      const netScore = Math.max(0, row.missScore - row.relearned);
      const status: TrainingFocusItem["status"] =
        netScore <= 0 && row.relearned > 0 ? "relearned" : "needs_training";
      return {
        concept: row.display,
        missScore: netScore > 0 ? netScore : row.relearned,
        status,
        label: status === "relearned" ? "재학습 성공됨" : "복습 필요",
      };
    })
    .filter((item) => item.status === "relearned" || item.missScore > 0)
    .sort((a, b) => {
      if (a.status !== b.status) {
        return a.status === "needs_training" ? -1 : 1;
      }
      return b.missScore - a.missScore;
    })
    .slice(0, 8);
}

export async function buildTrainingSnapshot(params: {
  userId: string;
  attempts: ProblemAttempt[];
  mistakes: PracticeMistakeRecord[];
  scanned: ScannedProblemRecord[];
  submissions: SolutionSubmission[];
}): Promise<TrainingSnapshot> {
  const focusItems = buildTrainingFocusItems({
    mistakes: params.mistakes,
    scanned: params.scanned,
    submissions: params.submissions,
  });
  const needsTraining = focusItems.filter(
    (item) => item.status === "needs_training" && item.missScore > 0,
  );

  const latestTrainingSet = await getLatestProblemSetWithSubmissionPrefix(
    trainingSubmissionId(params.userId),
  );

  let activeSetId: string | null = null;
  let remainingCount = 0;
  if (latestTrainingSet) {
    const answered = new Set(
      params.attempts
        .filter((attempt) => attempt.setId === latestTrainingSet.id)
        .map((attempt) => attempt.problemId),
    );
    const remaining = latestTrainingSet.problems.filter(
      (problem) => !answered.has(problem.id),
    );
    if (remaining.length > 0) {
      activeSetId = latestTrainingSet.id;
      remainingCount = remaining.length;
    }
  }

  const hasLearningData =
    params.mistakes.length > 0 ||
    params.scanned.length > 0 ||
    params.submissions.some(
      (submission) => submission.analysis.weakConcepts.length > 0,
    ) ||
    params.attempts.length > 0;

  const available =
    hasLearningData &&
    (needsTraining.length > 0 || activeSetId != null);

  const topConcepts = needsTraining.slice(0, 3).map((item) => item.concept);

  return {
    available,
    hasLearningData,
    headline: available ? "틀렸던 개념을 다시 연습해요" : "",
    description: available
      ? "분석·연습에서 틀린 부분을 모아 비슷한 문제로 반복 훈련합니다. 맞추면 [재학습 성공됨]으로 표시돼요."
      : "",
    focusConcepts: topConcepts,
    focusItems,
    activeSetId,
    remainingCount,
    totalMisses: params.mistakes.filter((mistake) => !mistake.resolvedAt).length,
    relearnedCount: params.mistakes.filter((mistake) => Boolean(mistake.resolvedAt))
      .length,
  };
}
