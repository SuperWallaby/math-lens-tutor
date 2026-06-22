import { randomUUID } from "crypto";

import { gradeToBand } from "./curriculum";
import { buildTrainingFocusItems } from "./concept-training";
import { enhanceFeedReasonsWithGpu } from "./gpu-llm";
import {
  bankItemToGeneratedProblem,
  pickPrimaryConcept,
  recordDeliveriesForProblems,
} from "./problem-bank";
import {
  findAvailableBankItems,
  findBankItemById,
  getPracticeMistakesForUser,
  getScannedProblemsForUser,
} from "./problem-bank-store";
import { getAttempts, getSubmissionsByUserId, saveProblemSet } from "./store";
import type {
  GeneratedProblemSet,
  ProblemBankItem,
  TrainingFeedItem,
  TrainingFeedResponse,
  UserConceptMastery,
  UserFeedQueue,
} from "./types";
import { findUserById } from "./users";
import {
  applyAttemptToMastery,
  buildFeedItemFromBank,
  computeTargetDifficulty,
  createEmptyMasteryEntry,
  claimNextAnalysisJob,
  enqueueAnalysisJob,
  finishAnalysisJob,
  getUserConceptMastery,
  getUserFeedQueue,
  hasPendingFeedRefresh,
  saveUserFeedQueue,
  saveUserConceptMastery,
} from "./training-feed-store";

export const FEED_QUEUE_SIZE = 10;
export const FEED_QUEUE_MAX_AGE_MS = 6 * 60 * 60 * 1000;

const DIFFICULTY_LABEL: Record<string, string> = {
  easy: "쉬움",
  medium: "보통",
  hard: "어려움",
};

function defaultReason(params: {
  concept: string;
  difficulty: string;
  missScore?: number;
}): string {
  if (params.missScore && params.missScore > 0) {
    return `${params.concept} · ${DIFFICULTY_LABEL[params.difficulty] ?? params.difficulty} · 오답 ${params.missScore}회 복습`;
  }
  return `${params.concept} · ${DIFFICULTY_LABEL[params.difficulty] ?? params.difficulty} · 맞춤 추천`;
}

function isQueueFresh(queue: UserFeedQueue | null): boolean {
  if (!queue || queue.items.length === 0) return false;
  const age = Date.now() - Date.parse(queue.updatedAt);
  return Number.isFinite(age) && age >= 0 && age <= FEED_QUEUE_MAX_AGE_MS;
}

async function loadFocusContext(userId: string) {
  const [attempts, submissions, mistakes, scanned, user] = await Promise.all([
    getAttempts(userId),
    getSubmissionsByUserId(userId, 30),
    getPracticeMistakesForUser(userId),
    getScannedProblemsForUser(userId),
    findUserById(userId),
  ]);

  const focusItems = buildTrainingFocusItems({ mistakes, scanned, submissions });
  const needsTraining = focusItems.filter(
    (item) => item.status === "needs_training" && item.missScore > 0,
  );

  return {
    attempts,
    submissions,
    mistakes,
    scanned,
    gradeBand: gradeToBand(user?.grade),
    focusItems,
    needsTraining,
    focusConcepts: needsTraining.slice(0, 5).map((item) => item.concept),
  };
}

function missScoreForConcept(
  focusItems: Awaited<ReturnType<typeof loadFocusContext>>["focusItems"],
  concept: string,
): number {
  const row = focusItems.find(
    (item) => item.concept.trim().toLowerCase() === concept.trim().toLowerCase(),
  );
  return row?.missScore ?? 0;
}

async function resolveTargetDifficulty(
  userId: string,
  concept: string,
): Promise<ProblemBankItem["difficulty"]> {
  const mastery = await getUserConceptMastery(userId);
  const key = concept.trim().toLowerCase();
  const entry = mastery?.concepts[key];
  if (entry) return entry.targetDifficulty;
  return "medium";
}

export async function buildFallbackFeedItems(params: {
  userId: string;
  limit?: number;
}): Promise<TrainingFeedItem[]> {
  const limit = params.limit ?? FEED_QUEUE_SIZE;
  const ctx = await loadFocusContext(params.userId);
  if (ctx.focusConcepts.length === 0) return [];

  const deliveredIds = new Set<string>();
  const items: TrainingFeedItem[] = [];

  for (const concept of ctx.focusConcepts) {
    if (items.length >= limit) break;
    const targetDifficulty = await resolveTargetDifficulty(params.userId, concept);
    const bankItems = await findAvailableBankItems({
      userId: params.userId,
      gradeBand: ctx.gradeBand,
      conceptTags: [concept],
      limit: 2,
      minDifficulty: targetDifficulty,
      deliveredIds,
      excludeDelivered: true,
    });

    for (const bankItem of bankItems) {
      if (items.length >= limit) break;
      deliveredIds.add(bankItem.id);
      items.push(
        buildFeedItemFromBank({
          item: bankItem,
          reason: defaultReason({
            concept,
            difficulty: bankItem.difficulty,
            missScore: missScoreForConcept(ctx.focusItems, concept),
          }),
        }),
      );
    }
  }

  if (items.length < limit) {
    const bankItems = await findAvailableBankItems({
      userId: params.userId,
      gradeBand: ctx.gradeBand,
      conceptTags: ctx.focusConcepts,
      limit: limit - items.length,
      deliveredIds,
      excludeDelivered: true,
    });
    for (const bankItem of bankItems) {
      if (items.some((item) => item.bankItemId === bankItem.id)) continue;
      items.push(
        buildFeedItemFromBank({
          item: bankItem,
          reason: defaultReason({
            concept: bankItem.conceptPrimary,
            difficulty: bankItem.difficulty,
            missScore: missScoreForConcept(ctx.focusItems, bankItem.conceptPrimary),
          }),
        }),
      );
    }
  }

  return items.slice(0, limit);
}

export async function refreshUserFeedQueue(userId: string): Promise<UserFeedQueue> {
  const ctx = await loadFocusContext(userId);
  const mastery: UserConceptMastery =
    (await getUserConceptMastery(userId)) ?? {
      userId,
      concepts: {},
      updatedAt: new Date().toISOString(),
    };

  for (const item of ctx.needsTraining) {
    const key = item.concept.trim().toLowerCase();
    if (!mastery.concepts[key]) {
      mastery.concepts[key] = createEmptyMasteryEntry(item.concept);
    } else {
      mastery.concepts[key].concept = item.concept;
      mastery.concepts[key].targetDifficulty = computeTargetDifficulty(
        mastery.concepts[key],
      );
    }
  }
  mastery.updatedAt = new Date().toISOString();
  await saveUserConceptMastery(mastery);

  let items = await buildFallbackFeedItems({ userId, limit: FEED_QUEUE_SIZE });
  items = await enhanceFeedReasonsWithGpu({
    userId,
    items,
    focusConcepts: ctx.focusConcepts,
  });

  const queue: UserFeedQueue = {
    userId,
    items,
    source: "precomputed",
    updatedAt: new Date().toISOString(),
  };
  await saveUserFeedQueue(queue);
  return queue;
}

export async function getTrainingFeedResponse(
  userId: string,
): Promise<TrainingFeedResponse> {
  const [queue, refreshPending] = await Promise.all([
    getUserFeedQueue(userId),
    hasPendingFeedRefresh(userId),
  ]);

  if (isQueueFresh(queue) && queue!.items.length > 0) {
    return {
      items: queue!.items,
      source: queue!.source,
      updatedAt: queue!.updatedAt,
      refreshPending,
    };
  }

  const fallbackItems = await buildFallbackFeedItems({ userId });
  void enqueueAnalysisJob({ userId, type: "refresh_user_feed" });

  return {
    items: fallbackItems,
    source: "fallback",
    updatedAt: queue?.updatedAt ?? null,
    refreshPending: true,
  };
}

export async function recordTrainingFeedActivity(params: {
  userId: string;
  conceptTags: string[];
  difficulty: ProblemBankItem["difficulty"];
  isCorrect: boolean;
}): Promise<void> {
  await applyAttemptToMastery({
    userId: params.userId,
    conceptTags: params.conceptTags,
    difficulty: params.difficulty,
    isCorrect: params.isCorrect,
  });
  await enqueueAnalysisJob({ userId: params.userId, type: "refresh_user_feed" });
}

export function feedSubmissionId(userId: string): string {
  return `feed:${userId}`;
}

export async function startFeedItemPractice(params: {
  userId: string;
  feedItemId?: string;
  bankItemId?: string;
}): Promise<{ problemSet: GeneratedProblemSet; feedItem: TrainingFeedItem | null }> {
  const queue = await getUserFeedQueue(params.userId);
  const fallback = queue?.items.length
    ? queue.items
    : await buildFallbackFeedItems({ userId: params.userId });

  let feedItem =
    fallback.find((item) => item.id === params.feedItemId) ??
    fallback.find((item) => item.bankItemId === params.bankItemId) ??
    null;

  const bankItemId = params.bankItemId ?? feedItem?.bankItemId;
  if (!bankItemId) {
    throw new Error("피드 문제를 찾을 수 없습니다.");
  }

  const bankItem = await findBankItemById(bankItemId);
  if (!bankItem) {
    throw new Error("문제 은행에서 문항을 찾을 수 없습니다.");
  }

  if (!feedItem) {
    feedItem = buildFeedItemFromBank({
      item: bankItem,
      reason: defaultReason({
        concept: bankItem.conceptPrimary,
        difficulty: bankItem.difficulty,
      }),
    });
  }

  const problemSetId = randomUUID();
  const problemId = randomUUID();
  const problem = bankItemToGeneratedProblem(bankItem, problemId);
  const submissionId = feedSubmissionId(params.userId);

  const problemSet = {
    id: problemSetId,
    submissionId,
    title: feedItem.title || `${bankItem.conceptPrimary} 맞춤 훈련`,
    learningGoal: feedItem.reason,
    problems: [problem],
  } as GeneratedProblemSet;

  await saveProblemSet(problemSet);

  await recordDeliveriesForProblems({
    userId: params.userId,
    submissionId,
    problemSetId,
    problems: [problem],
  });

  return { problemSet, feedItem };
}

export async function processNextAnalysisJob(): Promise<boolean> {
  const job = await claimNextAnalysisJob();
  if (!job) return false;

  try {
    if (job.type === "refresh_user_feed") {
      await refreshUserFeedQueue(job.userId);
    }
    await finishAnalysisJob({ jobId: job.id, status: "done" });
  } catch (error) {
    await finishAnalysisJob({
      jobId: job.id,
      status: "failed",
      error: error instanceof Error ? error.message : String(error),
    });
  }

  return true;
}
