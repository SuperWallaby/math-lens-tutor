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
import { refreshLearningProfileSnapshot } from "./learning-profile-snapshot";
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
/** 맞춤 피드 한 카드에 묶어 서빙하는 유사문제 수(1~3) */
export const FEED_ITEM_SET_SIZE = 3;

function defaultReason(params: {
  concept: string;
  difficulty: string;
  missScore?: number;
}): string {
  if (params.missScore && params.missScore > 0) {
    return `오답 ${params.missScore}회 복습`;
  }
  return "맞춤 추천";
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

  // 1) 약점 개념별로 최대 FEED_ITEM_SET_SIZE개를 묶어 하나의 세트(유사문제)로 서빙한다.
  for (const concept of ctx.focusConcepts) {
    if (items.length >= limit) break;
    const targetDifficulty = await resolveTargetDifficulty(params.userId, concept);
    const bankItems = await findAvailableBankItems({
      userId: params.userId,
      gradeBand: ctx.gradeBand,
      conceptTags: [concept],
      limit: FEED_ITEM_SET_SIZE,
      minDifficulty: targetDifficulty,
      deliveredIds,
      excludeDelivered: true,
    });

    if (bankItems.length === 0) continue;
    for (const bankItem of bankItems) deliveredIds.add(bankItem.id);
    items.push(
      buildFeedItemFromBank({
        items: bankItems,
        reason: defaultReason({
          concept,
          difficulty: bankItems[0]!.difficulty,
          missScore: missScoreForConcept(ctx.focusItems, concept),
        }),
      }),
    );
  }

  // 2) 슬롯이 남으면 개념 무관하게 추가 문항을 묶어 채운다.
  while (items.length < limit) {
    const bankItems = await findAvailableBankItems({
      userId: params.userId,
      gradeBand: ctx.gradeBand,
      conceptTags: ctx.focusConcepts,
      limit: FEED_ITEM_SET_SIZE,
      deliveredIds,
      excludeDelivered: true,
    });
    if (bankItems.length === 0) break;
    for (const bankItem of bankItems) deliveredIds.add(bankItem.id);
    items.push(
      buildFeedItemFromBank({
        items: bankItems,
        reason: defaultReason({
          concept: bankItems[0]!.conceptPrimary,
          difficulty: bankItems[0]!.difficulty,
          missScore: missScoreForConcept(ctx.focusItems, bankItems[0]!.conceptPrimary),
        }),
      }),
    );
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

/** 앱 홈/훈련 탭 진입 시 — 큐가 stale이면 백그라운드 refresh job 등록 */
export async function prewarmTrainingFeedIfNeeded(userId: string): Promise<void> {
  const [queue, refreshPending] = await Promise.all([
    getUserFeedQueue(userId),
    hasPendingFeedRefresh(userId),
  ]);
  if (refreshPending) return;
  if (isQueueFresh(queue) && (queue?.items.length ?? 0) > 0) return;
  await enqueueAnalysisJob({ userId, type: "refresh_user_feed" });
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
    fallback.find((item) =>
      item.bankItemId === params.bankItemId ||
      (item.bankItemIds ?? []).includes(params.bankItemId ?? ""),
    ) ??
    null;

  // 서빙할 은행 문항 id 목록 (번들 1~3). 구버전 큐(bankItemIds 없음)와 단일 요청도 지원.
  const rawIds = feedItem?.bankItemIds?.length
    ? feedItem.bankItemIds
    : feedItem
      ? [feedItem.bankItemId]
      : params.bankItemId
        ? [params.bankItemId]
        : [];
  const bankItemIds = rawIds.filter(
    (id, index, arr) => Boolean(id) && arr.indexOf(id) === index,
  );
  if (bankItemIds.length === 0) {
    throw new Error("피드 문제를 찾을 수 없습니다.");
  }

  const resolved = await Promise.all(
    bankItemIds.map((id) => findBankItemById(id)),
  );
  const bankItems = resolved.filter(
    (item): item is ProblemBankItem => Boolean(item),
  );
  if (bankItems.length === 0) {
    throw new Error("문제 은행에서 문항을 찾을 수 없습니다.");
  }

  if (!feedItem) {
    feedItem = buildFeedItemFromBank({
      items: bankItems,
      reason: defaultReason({
        concept: bankItems[0]!.conceptPrimary,
        difficulty: bankItems[0]!.difficulty,
      }),
    });
  }

  const problemSetId = randomUUID();
  const problems = bankItems.map((item) =>
    bankItemToGeneratedProblem(item, randomUUID()),
  );
  const submissionId = feedSubmissionId(params.userId);

  const problemSet = {
    id: problemSetId,
    submissionId,
    title: feedItem.title || `${bankItems[0]!.conceptPrimary} 맞춤 훈련`,
    learningGoal: feedItem.reason,
    problems,
  } as GeneratedProblemSet;

  await saveProblemSet(problemSet);

  await recordDeliveriesForProblems({
    userId: params.userId,
    submissionId,
    problemSetId,
    problems,
  });

  return { problemSet, feedItem };
}

export async function processNextAnalysisJob(): Promise<boolean> {
  const job = await claimNextAnalysisJob();
  if (!job) return false;

  try {
    if (job.type === "refresh_user_feed") {
      await refreshUserFeedQueue(job.userId);
    } else if (job.type === "refresh_user_profile") {
      await refreshLearningProfileSnapshot(job.userId);
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
