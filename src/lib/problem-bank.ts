import { randomUUID } from "crypto";

import type { AnalyzeQualityMode } from "./analyze-mode";
import { generateSimilarProblems } from "./azure";
import { gradeToBand } from "./curriculum";
import {
  findAvailableBankItems,
  hashProblemContent,
  insertBankItem,
  savePracticeMistakeRecord,
  saveScannedProblemRecord,
  saveUserProblemDeliveries,
  updateDeliveryOutcome,
} from "./problem-bank-store";
import { studyLog } from "./server-log";
import type {
  GeneratedProblem,
  GeneratedProblemSet,
  PracticeMistakeRecord,
  ProblemAttempt,
  ProblemBankItem,
  ScannedProblemRecord,
  SolutionAnalysis,
  SolutionSubmission,
  UserProblemDelivery,
} from "./types";
import {
  meaningfulRecommendedFocus,
  meaningfulWeakConcepts,
} from "./types";

const SET_SIZE = 5;

export function extractConceptTagsFromAnalysis(analysis: SolutionAnalysis): string[] {
  const tags = [
    ...meaningfulWeakConcepts(analysis.weakConcepts),
    ...meaningfulRecommendedFocus(analysis.recommendedFocus),
  ];
  const normalized = tags
    .map((tag) => tag.trim())
    .filter(Boolean)
    .filter((tag, index, arr) => arr.indexOf(tag) === index);
  if (normalized.length > 0) return normalized;
  if (analysis.errorSummary.trim()) {
    return [analysis.errorSummary.trim().slice(0, 80)];
  }
  return ["수학 연습"];
}

export function pickPrimaryConcept(conceptTags: string[]): string {
  return conceptTags[0]?.trim() || "수학 연습";
}

function bankItemToProblem(
  item: ProblemBankItem,
  problemId: string,
): GeneratedProblem {
  return {
    id: problemId,
    type: item.type,
    title: item.title,
    prompt: item.prompt,
    choices: item.choices,
    correctAnswer: item.correctAnswer,
    explanation: item.explanation,
    difficulty: item.difficulty,
    conceptTags: item.conceptTags,
    chart: item.chart,
    jsxGraph: item.jsxGraph,
    source: "bank",
    bankItemId: item.id,
  };
}

export async function ingestGeneratedProblems(params: {
  problems: GeneratedProblem[];
  gradeBand: string;
  originSubmissionId?: string;
}): Promise<ProblemBankItem[]> {
  const stored: ProblemBankItem[] = [];

  for (const problem of params.problems) {
    const conceptTags = problem.conceptTags.map((t) => t.trim()).filter(Boolean);
    const contentHash = hashProblemContent({
      prompt: problem.prompt,
      correctAnswer: problem.correctAnswer,
      conceptTags,
    });

    const item: ProblemBankItem = {
      id: randomUUID(),
      contentHash,
      type: problem.type,
      title: problem.title,
      prompt: problem.prompt,
      choices: problem.choices,
      correctAnswer: problem.correctAnswer,
      explanation: problem.explanation,
      difficulty: problem.difficulty,
      conceptTags,
      conceptPrimary: pickPrimaryConcept(conceptTags),
      gradeBand: params.gradeBand,
      source: "ai_generated",
      originSubmissionId: params.originSubmissionId,
      active: true,
      deliveryCount: 0,
      chart: problem.chart,
      jsxGraph: problem.jsxGraph,
      createdAt: new Date().toISOString(),
    };

    const saved = await insertBankItem(item);
    stored.push(saved);
  }

  return stored;
}

async function recordDeliveriesForProblems(params: {
  userId: string;
  submissionId: string;
  problemSetId: string;
  problems: GeneratedProblem[];
}): Promise<void> {
  const deliveries: UserProblemDelivery[] = [];

  for (const problem of params.problems) {
    if (!problem.bankItemId) continue;
    deliveries.push({
      id: randomUUID(),
      userId: params.userId,
      bankItemId: problem.bankItemId,
      problemSetId: params.problemSetId,
      submissionId: params.submissionId,
      problemId: problem.id,
      deliveredAt: new Date().toISOString(),
      outcome: "pending",
    });
  }

  await saveUserProblemDeliveries(deliveries);
}

export async function resolvePracticeProblemSet(params: {
  userId: string;
  analysis: SolutionAnalysis;
  submissionId: string;
  problemSetId: string;
  grade?: string | null;
  generateOptions: {
    deploymentName: string;
    mode: AnalyzeQualityMode;
    fromVisionOcrOnly?: boolean;
  };
}): Promise<GeneratedProblemSet> {
  const conceptTags = extractConceptTagsFromAnalysis(params.analysis);
  const gradeBand = gradeToBand(params.grade);
  const fromBank = await findAvailableBankItems({
    userId: params.userId,
    gradeBand,
    conceptTags,
    limit: SET_SIZE,
  });

  studyLog("problem-bank", "select", {
    userId: params.userId,
    gradeBand,
    conceptTags,
    fromBank: fromBank.length,
  });

  const problems: GeneratedProblem[] = fromBank.map((item) =>
    bankItemToProblem(item, randomUUID()),
  );

  const needed = SET_SIZE - problems.length;
  let newlyGeneratedCount = 0;
  if (needed > 0) {
    const generatedSet = await generateSimilarProblems(
      params.analysis,
      params.submissionId,
      {
        deploymentName: params.generateOptions.deploymentName,
        mode: params.generateOptions.mode,
        problemSetId: params.problemSetId,
        fromVisionOcrOnly: params.generateOptions.fromVisionOcrOnly,
        problemCount: needed,
      },
    );

    const ingested = await ingestGeneratedProblems({
      problems: generatedSet.problems,
      gradeBand,
      originSubmissionId: params.submissionId,
    });
    newlyGeneratedCount = ingested.length;

    for (let i = 0; i < generatedSet.problems.length; i += 1) {
      const bankItem = ingested[i];
      if (!bankItem) continue;
      problems.push(
        bankItemToProblem(bankItem, randomUUID()),
      );
    }
  }

  const title =
    conceptTags.length > 0
      ? `${pickPrimaryConcept(conceptTags)} 유사문제 훈련`
      : "유사문제 훈련";
  const learningGoal =
    meaningfulRecommendedFocus(params.analysis.recommendedFocus)[0] ??
    meaningfulWeakConcepts(params.analysis.weakConcepts)[0] ??
    "틀린 유형을 반복 연습해 개념을 익힙니다.";

  const problemSet: GeneratedProblemSet = {
    id: params.problemSetId,
    submissionId: params.submissionId,
    title,
    learningGoal,
    problems: problems.slice(0, SET_SIZE),
  };

  await recordDeliveriesForProblems({
    userId: params.userId,
    submissionId: params.submissionId,
    problemSetId: params.problemSetId,
    problems: problemSet.problems,
  });

  studyLog("problem-bank", "deliver", {
    userId: params.userId,
    problemSetId: params.problemSetId,
    reusedFromBankCount: fromBank.length,
    newlyGeneratedCount,
  });

  return problemSet;
}

export async function indexScannedSubmission(
  submission: SolutionSubmission,
  grade?: string | null,
): Promise<ScannedProblemRecord> {
  const conceptTags = extractConceptTagsFromAnalysis(submission.analysis);
  const record: ScannedProblemRecord = {
    id: randomUUID(),
    userId: submission.userId,
    submissionId: submission.id,
    imageUrl: submission.imageUrl,
    imageName: submission.imageName,
    problemText: submission.analysis.problemText,
    extractedStudentAnswer: submission.analysis.extractedStudentAnswer,
    inferredCorrectAnswer: submission.analysis.inferredCorrectAnswer,
    errorSummary: submission.analysis.errorSummary,
    solutionSteps: submission.analysis.solutionSteps,
    weakConcepts: meaningfulWeakConcepts(submission.analysis.weakConcepts),
    recommendedFocus: meaningfulRecommendedFocus(submission.analysis.recommendedFocus),
    conceptTags,
    conceptPrimary: pickPrimaryConcept(conceptTags),
    gradeBand: gradeToBand(grade),
    createdAt: submission.createdAt,
  };

  return saveScannedProblemRecord(record);
}

export async function recordPracticeAttempt(params: {
  attempt: ProblemAttempt;
  problem: GeneratedProblem;
  expectedAnswer: string;
}): Promise<void> {
  if (params.problem.bankItemId) {
    await updateDeliveryOutcome({
      userId: params.attempt.userId,
      bankItemId: params.problem.bankItemId,
      problemSetId: params.attempt.setId,
      problemId: params.attempt.problemId,
      outcome: params.attempt.isCorrect ? "correct" : "incorrect",
      attemptId: params.attempt.id,
    });
  }

  if (params.attempt.isCorrect) return;

  const conceptTags = params.problem.conceptTags.map((t) => t.trim()).filter(Boolean);
  const mistake: PracticeMistakeRecord = {
    id: randomUUID(),
    userId: params.attempt.userId,
    attemptId: params.attempt.id,
    setId: params.attempt.setId,
    problemId: params.attempt.problemId,
    bankItemId: params.problem.bankItemId,
    answer: params.attempt.answer,
    expectedAnswer: params.expectedAnswer,
    conceptTags,
    conceptPrimary: pickPrimaryConcept(conceptTags),
    feedback: params.attempt.feedback,
    createdAt: params.attempt.createdAt,
  };

  await savePracticeMistakeRecord(mistake);
}
