import { createHash } from "crypto";

import { difficultyRank, meetsMinDifficulty } from "./problem-difficulty";
import { getMongoDb } from "./mongodb";
import type {
  GeneratedProblem,
  PracticeMistakeRecord,
  ProblemBankItem,
  ScannedProblemRecord,
  UserProblemDelivery,
} from "./types";

type MemoryProblemBankDb = {
  bankItems: ProblemBankItem[];
  deliveries: UserProblemDelivery[];
  scannedProblems: ScannedProblemRecord[];
  practiceMistakes: PracticeMistakeRecord[];
};

const globalForProblemBank = globalThis as typeof globalThis & {
  mathTutorProblemBankDb?: MemoryProblemBankDb;
};

const memoryProblemBankDb =
  globalForProblemBank.mathTutorProblemBankDb ??
  (globalForProblemBank.mathTutorProblemBankDb = {
    bankItems: [],
    deliveries: [],
    scannedProblems: [],
    practiceMistakes: [],
  });

let indexesEnsured = false;

export async function ensureProblemBankIndexes() {
  if (indexesEnsured) return;
  const db = await getMongoDb();
  if (!db) {
    indexesEnsured = true;
    return;
  }

  await Promise.all([
    db.collection<ProblemBankItem>("problem_bank_items").createIndex(
      { contentHash: 1 },
      { unique: true },
    ),
    db.collection<ProblemBankItem>("problem_bank_items").createIndex({
      active: 1,
      gradeBand: 1,
      conceptPrimary: 1,
    }),
    db.collection<ProblemBankItem>("problem_bank_items").createIndex({
      conceptTags: 1,
    }),
    db.collection<ProblemBankItem>("problem_bank_items").createIndex({
      active: 1,
      gradeBand: 1,
      unitId: 1,
      deliveryCount: 1,
      createdAt: -1,
    }),
    db.collection<UserProblemDelivery>("user_problem_deliveries").createIndex(
      { userId: 1, bankItemId: 1 },
      { unique: true },
    ),
    db.collection<UserProblemDelivery>("user_problem_deliveries").createIndex({
      userId: 1,
      deliveredAt: -1,
    }),
    db.collection<ScannedProblemRecord>("scanned_problem_records").createIndex(
      { submissionId: 1 },
      { unique: true },
    ),
    db.collection<ScannedProblemRecord>("scanned_problem_records").createIndex({
      userId: 1,
      createdAt: -1,
    }),
    db.collection<PracticeMistakeRecord>("practice_mistake_records").createIndex(
      { attemptId: 1 },
      { unique: true },
    ),
    db.collection<PracticeMistakeRecord>("practice_mistake_records").createIndex({
      userId: 1,
      createdAt: -1,
    }),
  ]);

  indexesEnsured = true;
}

const UNIT_POOL_COUNT_TTL_MS = 60_000;
const unitPoolCountCache = new Map<
  string,
  { count: number; expiresAt: number }
>();

export function invalidateUnitPoolCountCache(unitId?: string) {
  if (!unitId) {
    unitPoolCountCache.clear();
    return;
  }
  unitPoolCountCache.delete(unitId.trim());
}

/** 단원별 bank 풀 크기 — countDocuments 반복을 줄입니다 (UI 표시 없음). */
export async function getActiveBankCountByUnit(unitId: string): Promise<number> {
  const normalized = unitId.trim();
  if (!normalized) return 0;

  const cached = unitPoolCountCache.get(normalized);
  if (cached && cached.expiresAt > Date.now()) {
    return cached.count;
  }

  const count = await countActiveBankItemsByUnit(normalized);
  unitPoolCountCache.set(normalized, {
    count,
    expiresAt: Date.now() + UNIT_POOL_COUNT_TTL_MS,
  });
  return count;
}

export async function usesMemoryProblemBankStore(): Promise<boolean> {
  const store = await requireProblemBankStore();
  return "bankItems" in store;
}

function deliveryExcludeLookupStages(userId: string) {
  return [
    {
      $lookup: {
        from: "user_problem_deliveries",
        let: { bankItemId: "$id" },
        pipeline: [
          {
            $match: {
              $expr: {
                $and: [
                  { $eq: ["$bankItemId", "$$bankItemId"] },
                  { $eq: ["$userId", userId] },
                ],
              },
            },
          },
          { $limit: 1 },
        ],
        as: "_delivered",
      },
    },
    { $match: { _delivered: { $size: 0 } } },
    { $project: { _delivered: 0 } },
  ];
}

async function requireProblemBankStore() {
  await ensureProblemBankIndexes();
  const db = await getMongoDb();
  if (!db) {
    return memoryProblemBankDb;
  }
  return db;
}

export function hashProblemContent(input: {
  prompt: string;
  correctAnswer: string;
  conceptTags: string[];
}): string {
  const normalized = [
    input.prompt.replace(/\s+/g, " ").trim().toLowerCase(),
    input.correctAnswer.replace(/\s+/g, " ").trim().toLowerCase(),
    [...input.conceptTags].map((t) => t.trim().toLowerCase()).sort().join("|"),
  ].join("::");
  return createHash("sha256").update(normalized).digest("hex");
}

export async function findBankItemByHash(
  contentHash: string,
): Promise<ProblemBankItem | null> {
  const store = await requireProblemBankStore();
  if ("bankItems" in store) {
    return store.bankItems.find((item) => item.contentHash === contentHash) ?? null;
  }

  return store
    .collection<ProblemBankItem>("problem_bank_items")
    .findOne({ contentHash }, { projection: { _id: 0 } });
}

export async function findBankItemById(
  bankItemId: string,
): Promise<ProblemBankItem | null> {
  const normalized = bankItemId.trim();
  if (!normalized) return null;
  const store = await requireProblemBankStore();
  if ("bankItems" in store) {
    return store.bankItems.find((item) => item.id === normalized) ?? null;
  }

  return store
    .collection<ProblemBankItem>("problem_bank_items")
    .findOne({ id: normalized, active: true }, { projection: { _id: 0 } });
}

export async function insertBankItem(
  item: ProblemBankItem,
): Promise<ProblemBankItem> {
  const store = await requireProblemBankStore();
  if ("bankItems" in store) {
    const existing = store.bankItems.find((i) => i.contentHash === item.contentHash);
    if (existing) return existing;
    store.bankItems.unshift(item);
    if (item.unitId?.trim()) {
      invalidateUnitPoolCountCache(item.unitId);
    }
    return item;
  }

  try {
    await store.collection<ProblemBankItem>("problem_bank_items").insertOne(item);
    if (item.unitId?.trim()) {
      invalidateUnitPoolCountCache(item.unitId);
    }
    return item;
  } catch (error) {
    const duplicate =
      error instanceof Error &&
      (error.message.includes("E11000") || error.message.includes("duplicate key"));
    if (duplicate) {
      const existing = await findBankItemByHash(item.contentHash);
      if (existing) return existing;
    }
    throw error;
  }
}

export async function incrementBankItemDeliveryCount(
  bankItemId: string,
): Promise<void> {
  const store = await requireProblemBankStore();
  if ("bankItems" in store) {
    const item = store.bankItems.find((i) => i.id === bankItemId);
    if (item) item.deliveryCount += 1;
    return;
  }

  await store.collection<ProblemBankItem>("problem_bank_items").updateOne(
    { id: bankItemId },
    { $inc: { deliveryCount: 1 } },
  );
}

export async function getDeliveredBankItemIds(userId: string): Promise<Set<string>> {
  const store = await requireProblemBankStore();
  if ("deliveries" in store) {
    return new Set(
      store.deliveries
        .filter((d) => d.userId === userId)
        .map((d) => d.bankItemId),
    );
  }

  const rows = await store
    .collection<UserProblemDelivery>("user_problem_deliveries")
    .find({ userId }, { projection: { bankItemId: 1, _id: 0 } })
    .toArray();

  return new Set(rows.map((row) => row.bankItemId));
}

export async function findAvailableBankItems(params: {
  userId: string;
  gradeBand: string;
  conceptTags: string[];
  limit: number;
  minDifficulty?: GeneratedProblem["difficulty"];
  preferHarder?: boolean;
  excludeDelivered?: boolean;
  deliveredIds?: ReadonlySet<string>;
}): Promise<ProblemBankItem[]> {
  const excludeDelivered = params.excludeDelivered !== false;
  const delivered =
    excludeDelivered
      ? (params.deliveredIds ?? (await getDeliveredBankItemIds(params.userId)))
      : new Set<string>();
  const store = await requireProblemBankStore();
  const normalizedTargets = params.conceptTags.map((t) => t.trim().toLowerCase());

  let candidates: ProblemBankItem[] = [];
  if ("bankItems" in store) {
    candidates = store.bankItems.filter(
      (item) =>
        item.active &&
        item.gradeBand === params.gradeBand &&
        !delivered.has(item.id),
    );
  } else {
    const pipeline: Record<string, unknown>[] = [
      {
        $match: {
          active: true,
          gradeBand: params.gradeBand,
        },
      },
    ];
    if (excludeDelivered) {
      pipeline.push(...deliveryExcludeLookupStages(params.userId));
    }
    pipeline.push(
      { $sort: { deliveryCount: 1, createdAt: -1 } },
      { $limit: Math.max(params.limit * 8, 40) },
      { $project: { _id: 0 } },
    );
    candidates = await store
      .collection<ProblemBankItem>("problem_bank_items")
      .aggregate<ProblemBankItem>(pipeline)
      .toArray();
  }

  const scored = candidates
    .map((item) => {
      const tags = item.conceptTags.map((t) => t.trim().toLowerCase());
      const overlap = tags.filter((tag) =>
        normalizedTargets.some(
          (target) => tag.includes(target) || target.includes(tag),
        ),
      ).length;
      const primaryMatch = normalizedTargets.some(
        (target) =>
          item.conceptPrimary.toLowerCase().includes(target) ||
          target.includes(item.conceptPrimary.toLowerCase()),
      )
        ? 2
        : 0;
      const difficultyBonus = params.preferHarder
        ? difficultyRank(item.difficulty) * 0.5
        : 0;
      return { item, score: overlap + primaryMatch + difficultyBonus };
    })
    .filter((row) => row.score > 0)
    .filter(
      (row) =>
        !params.minDifficulty ||
        meetsMinDifficulty(row.item.difficulty, params.minDifficulty),
    )
    .sort((a, b) => {
      if (params.preferHarder && b.item.difficulty !== a.item.difficulty) {
        return difficultyRank(b.item.difficulty) - difficultyRank(a.item.difficulty);
      }
      if (b.score !== a.score) return b.score - a.score;
      if (a.item.deliveryCount !== b.item.deliveryCount) {
        return a.item.deliveryCount - b.item.deliveryCount;
      }
      return b.item.createdAt.localeCompare(a.item.createdAt);
    });

  const picked: ProblemBankItem[] = [];
  const usedPrimary = new Set<string>();
  for (const row of scored) {
    if (picked.length >= params.limit) break;
    if (usedPrimary.has(row.item.conceptPrimary) && picked.length < params.limit - 1) {
      continue;
    }
    picked.push(row.item);
    usedPrimary.add(row.item.conceptPrimary);
  }

  if (picked.length < params.limit) {
    for (const row of scored) {
      if (picked.length >= params.limit) break;
      if (picked.some((p) => p.id === row.item.id)) continue;
      picked.push(row.item);
    }
  }

  return picked.slice(0, params.limit);
}

export async function countActiveBankItemsByUnit(unitId: string): Promise<number> {
  const normalized = unitId.trim();
  if (!normalized) return 0;
  const store = await requireProblemBankStore();

  if ("bankItems" in store) {
    return store.bankItems.filter(
      (item) => item.active && item.unitId === normalized,
    ).length;
  }

  return store.collection<ProblemBankItem>("problem_bank_items").countDocuments({
    active: true,
    unitId: normalized,
  });
}

export type UnitPracticeAggregate = {
  attemptedUnique: number;
  correctUnique: number;
  gradedCount: number;
  correctCount: number;
};

const UNIT_PRACTICE_SUBMISSION_PREFIX = "unit:";

/** 진도탭 단원 학습 submissionId(`unit:<id>`)에서 단원 ID 추출. 그 외 소스는 제외. */
function unitIdFromUnitSubmission(submissionId?: string): string | null {
  if (!submissionId || !submissionId.startsWith(UNIT_PRACTICE_SUBMISSION_PREFIX)) {
    return null;
  }
  const unitId = submissionId.slice(UNIT_PRACTICE_SUBMISSION_PREFIX.length).trim();
  return unitId || null;
}

/**
 * 단원별 누적 연습 — 진도탭 단원 학습(`submissionId = "unit:<id>"`)에서 푼 것만 집계.
 * 훈련 피드·홈 유사문제 등 다른 경로의 풀이는 진도율에 반영하지 않는다.
 */
export async function aggregateUnitPracticeForUser(
  userId: string,
): Promise<Map<string, UnitPracticeAggregate>> {
  const store = await requireProblemBankStore();

  type Mutable = {
    attempted: Set<string>;
    correct: Set<string>;
    graded: number;
    correctGrades: number;
  };
  const byUnit = new Map<string, Mutable>();

  const bump = (unitId: string, bankItemId: string, outcome: UserProblemDelivery["outcome"]) => {
    const row =
      byUnit.get(unitId) ??
      ({
        attempted: new Set<string>(),
        correct: new Set<string>(),
        graded: 0,
        correctGrades: 0,
      } satisfies Mutable);
    row.attempted.add(bankItemId);
    if (outcome === "correct" || outcome === "incorrect") {
      row.graded += 1;
      if (outcome === "correct") {
        row.correctGrades += 1;
        row.correct.add(bankItemId);
      }
    }
    byUnit.set(unitId, row);
  };

  if ("deliveries" in store) {
    for (const delivery of store.deliveries) {
      if (delivery.userId !== userId) continue;
      const unitId = unitIdFromUnitSubmission(delivery.submissionId);
      if (!unitId) continue;
      bump(unitId, delivery.bankItemId, delivery.outcome);
    }
  } else {
    const deliveries = await store
      .collection<UserProblemDelivery>("user_problem_deliveries")
      .find(
        {
          userId,
          submissionId: { $regex: `^${UNIT_PRACTICE_SUBMISSION_PREFIX}` },
        },
        { projection: { bankItemId: 1, outcome: 1, submissionId: 1, _id: 0 } },
      )
      .toArray();

    for (const delivery of deliveries) {
      const unitId = unitIdFromUnitSubmission(delivery.submissionId);
      if (!unitId) continue;
      bump(unitId, delivery.bankItemId, delivery.outcome);
    }
  }

  const out = new Map<string, UnitPracticeAggregate>();
  for (const [unitId, row] of byUnit) {
    out.set(unitId, {
      attemptedUnique: row.attempted.size,
      correctUnique: row.correct.size,
      gradedCount: row.graded,
      correctCount: row.correctGrades,
    });
  }
  return out;
}

const UNIT_GROUPED_COUNT_TTL_MS = 10 * 60 * 1000;
let groupedUnitCountCache: {
  counts: Map<string, number>;
  expiresAt: number;
} | null = null;

export function invalidateGroupedUnitCountCache() {
  groupedUnitCountCache = null;
}

export async function countActiveBankItemsGroupedByUnit(): Promise<Map<string, number>> {
  if (
    groupedUnitCountCache &&
    groupedUnitCountCache.expiresAt > Date.now()
  ) {
    return groupedUnitCountCache.counts;
  }

  const store = await requireProblemBankStore();
  const counts = new Map<string, number>();

  if ("bankItems" in store) {
    for (const item of store.bankItems) {
      if (!item.active || !item.unitId?.trim()) continue;
      const id = item.unitId.trim();
      counts.set(id, (counts.get(id) ?? 0) + 1);
    }
    groupedUnitCountCache = {
      counts,
      expiresAt: Date.now() + UNIT_GROUPED_COUNT_TTL_MS,
    };
    return counts;
  }

  const rows = await store
    .collection<ProblemBankItem>("problem_bank_items")
    .aggregate<{ _id: string; count: number }>([
      { $match: { active: true, unitId: { $exists: true, $ne: "" } } },
      { $group: { _id: "$unitId", count: { $sum: 1 } } },
    ])
    .toArray();

  for (const row of rows) {
    if (row._id?.trim()) counts.set(row._id.trim(), row.count);
  }
  groupedUnitCountCache = {
    counts,
    expiresAt: Date.now() + UNIT_GROUPED_COUNT_TTL_MS,
  };
  return counts;
}

export async function findBankItemsByUnit(params: {
  userId: string;
  gradeBand: string;
  unitId: string;
  limit: number;
  minDifficulty?: GeneratedProblem["difficulty"];
  preferHarder?: boolean;
  excludeDelivered?: boolean;
  deliveredIds?: ReadonlySet<string>;
}): Promise<ProblemBankItem[]> {
  const normalizedUnitId = params.unitId.trim();
  if (!normalizedUnitId) return [];

  const excludeDelivered = params.excludeDelivered !== false;
  const delivered =
    excludeDelivered
      ? (params.deliveredIds ?? (await getDeliveredBankItemIds(params.userId)))
      : new Set<string>();
  const store = await requireProblemBankStore();

  let candidates: ProblemBankItem[] = [];
  if ("bankItems" in store) {
    candidates = store.bankItems.filter(
      (item) =>
        item.active &&
        item.gradeBand === params.gradeBand &&
        item.unitId === normalizedUnitId &&
        !delivered.has(item.id),
    );
  } else {
    const pipeline: Record<string, unknown>[] = [
      {
        $match: {
          active: true,
          gradeBand: params.gradeBand,
          unitId: normalizedUnitId,
        },
      },
    ];
    if (excludeDelivered) {
      pipeline.push(...deliveryExcludeLookupStages(params.userId));
    }
    pipeline.push(
      { $sort: { deliveryCount: 1, createdAt: -1 } },
      { $limit: Math.max(params.limit, 20) },
      { $project: { _id: 0 } },
    );
    candidates = await store
      .collection<ProblemBankItem>("problem_bank_items")
      .aggregate<ProblemBankItem>(pipeline)
      .toArray();
  }

  return candidates
    .filter(
      (item) =>
        !params.minDifficulty ||
        meetsMinDifficulty(item.difficulty, params.minDifficulty),
    )
    .sort((a, b) => {
      if (params.preferHarder && a.difficulty !== b.difficulty) {
        return difficultyRank(b.difficulty) - difficultyRank(a.difficulty);
      }
      if (a.deliveryCount !== b.deliveryCount) {
        return a.deliveryCount - b.deliveryCount;
      }
      return b.createdAt.localeCompare(a.createdAt);
    })
    .slice(0, params.limit);
}

export async function saveUserProblemDeliveries(
  deliveries: UserProblemDelivery[],
): Promise<void> {
  if (deliveries.length === 0) return;
  const store = await requireProblemBankStore();

  if ("deliveries" in store) {
    for (const delivery of deliveries) {
      const exists = store.deliveries.some(
        (d) => d.userId === delivery.userId && d.bankItemId === delivery.bankItemId,
      );
      if (!exists) {
        store.deliveries.unshift(delivery);
        await incrementBankItemDeliveryCount(delivery.bankItemId);
      }
    }
    return;
  }

  for (const delivery of deliveries) {
    try {
      await store
        .collection<UserProblemDelivery>("user_problem_deliveries")
        .insertOne(delivery);
      await incrementBankItemDeliveryCount(delivery.bankItemId);
    } catch (error) {
      const duplicate =
        error instanceof Error &&
        (error.message.includes("E11000") || error.message.includes("duplicate key"));
      if (!duplicate) throw error;
    }
  }
}

export async function updateDeliveryOutcome(params: {
  userId: string;
  bankItemId: string;
  problemSetId: string;
  problemId: string;
  outcome: "correct" | "incorrect";
  attemptId: string;
}): Promise<void> {
  const store = await requireProblemBankStore();
  const patch = {
    outcome: params.outcome,
    attemptId: params.attemptId,
  };

  if ("deliveries" in store) {
    const row = store.deliveries.find(
      (d) =>
        d.userId === params.userId &&
        d.bankItemId === params.bankItemId &&
        d.problemSetId === params.problemSetId &&
        d.problemId === params.problemId,
    );
    if (row) Object.assign(row, patch);
    return;
  }

  await store.collection<UserProblemDelivery>("user_problem_deliveries").updateOne(
    {
      userId: params.userId,
      bankItemId: params.bankItemId,
      problemSetId: params.problemSetId,
      problemId: params.problemId,
    },
    { $set: patch },
  );
}

export async function saveScannedProblemRecord(
  record: ScannedProblemRecord,
): Promise<ScannedProblemRecord> {
  const store = await requireProblemBankStore();
  if ("scannedProblems" in store) {
    const existing = store.scannedProblems.find((r) => r.submissionId === record.submissionId);
    if (existing) return existing;
    store.scannedProblems.unshift(record);
    return record;
  }

  try {
    await store.collection<ScannedProblemRecord>("scanned_problem_records").insertOne(record);
  } catch (error) {
    const duplicate =
      error instanceof Error &&
      (error.message.includes("E11000") || error.message.includes("duplicate key"));
    if (duplicate) {
      const existing = await store
        .collection<ScannedProblemRecord>("scanned_problem_records")
        .findOne({ submissionId: record.submissionId }, { projection: { _id: 0 } });
      if (existing) return existing;
    } else {
      throw error;
    }
  }

  return record;
}

export async function savePracticeMistakeRecord(
  record: PracticeMistakeRecord,
): Promise<PracticeMistakeRecord> {
  const store = await requireProblemBankStore();
  if ("practiceMistakes" in store) {
    const existing = store.practiceMistakes.find((r) => r.attemptId === record.attemptId);
    if (existing) return existing;
    store.practiceMistakes.unshift(record);
    return record;
  }

  try {
    await store.collection<PracticeMistakeRecord>("practice_mistake_records").insertOne(record);
  } catch (error) {
    const duplicate =
      error instanceof Error &&
      (error.message.includes("E11000") || error.message.includes("duplicate key"));
    if (duplicate) {
      const existing = await store
        .collection<PracticeMistakeRecord>("practice_mistake_records")
        .findOne({ attemptId: record.attemptId }, { projection: { _id: 0 } });
      if (existing) return existing;
    } else {
      throw error;
    }
  }

  return record;
}

export async function getPracticeMistakesForUser(
  userId: string,
  limit = 50,
): Promise<PracticeMistakeRecord[]> {
  const store = await requireProblemBankStore();
  if ("practiceMistakes" in store) {
    return store.practiceMistakes
      .filter((record) => record.userId === userId)
      .slice(0, limit);
  }

  return store
    .collection<PracticeMistakeRecord>("practice_mistake_records")
    .find({ userId }, { projection: { _id: 0 } })
    .sort({ createdAt: -1 })
    .limit(limit)
    .toArray();
}

export async function resolvePracticeMistakesForRelearn(params: {
  userId: string;
  conceptTags: string[];
  conceptPrimary: string;
  attemptId: string;
}): Promise<string[]> {
  const store = await requireProblemBankStore();
  const targets = [params.conceptPrimary, ...params.conceptTags]
    .map((value) => value.trim())
    .filter(Boolean);
  if (targets.length === 0) return [];

  const relearned: string[] = [];
  const now = new Date().toISOString();

  const matches = (record: PracticeMistakeRecord) => {
    if (record.userId !== params.userId || record.resolvedAt) return false;
    const recordConcepts = [record.conceptPrimary, ...record.conceptTags];
    return recordConcepts.some((concept) =>
      targets.some((target) => {
        const x = concept.trim().toLowerCase();
        const y = target.trim().toLowerCase();
        return x === y || x.includes(y) || y.includes(x);
      }),
    );
  };

  if ("practiceMistakes" in store) {
    const unresolved = store.practiceMistakes
      .filter(matches)
      .sort((a, b) => b.createdAt.localeCompare(a.createdAt));
    const target = unresolved[0];
    if (!target) return [];
    target.resolvedAt = now;
    target.resolveAttemptId = params.attemptId;
    relearned.push(target.conceptPrimary.trim() || targets[0]!);
    return relearned;
  }

  const candidate = await store
    .collection<PracticeMistakeRecord>("practice_mistake_records")
    .findOne(
      {
        userId: params.userId,
        resolvedAt: { $exists: false },
        $or: [
          { conceptPrimary: { $in: targets } },
          { conceptTags: { $in: targets } },
        ],
      },
      { projection: { _id: 0 }, sort: { createdAt: -1 } },
    );

  if (!candidate) return [];

  await store.collection<PracticeMistakeRecord>("practice_mistake_records").updateOne(
    { id: candidate.id },
    {
      $set: {
        resolvedAt: now,
        resolveAttemptId: params.attemptId,
      },
    },
  );

  relearned.push(candidate.conceptPrimary.trim() || targets[0]!);
  return relearned;
}

export async function getScannedProblemsForUser(
  userId: string,
  limit = 30,
): Promise<ScannedProblemRecord[]> {
  const store = await requireProblemBankStore();
  if ("scannedProblems" in store) {
    return store.scannedProblems
      .filter((record) => record.userId === userId)
      .slice(0, limit);
  }

  return store
    .collection<ScannedProblemRecord>("scanned_problem_records")
    .find({ userId }, { projection: { _id: 0 } })
    .sort({ createdAt: -1 })
    .limit(limit)
    .toArray();
}

export async function reassignProblemBankUserData(
  fromUserId: string,
  toUserId: string,
): Promise<void> {
  const db = await getMongoDb();
  if (!db) {
    for (const delivery of memoryProblemBankDb.deliveries) {
      if (delivery.userId === fromUserId) delivery.userId = toUserId;
    }
    for (const scanned of memoryProblemBankDb.scannedProblems) {
      if (scanned.userId === fromUserId) scanned.userId = toUserId;
    }
    for (const mistake of memoryProblemBankDb.practiceMistakes) {
      if (mistake.userId === fromUserId) mistake.userId = toUserId;
    }
    return;
  }

  await Promise.all([
    db.collection("user_problem_deliveries").updateMany(
      { userId: fromUserId },
      { $set: { userId: toUserId } },
    ),
    db.collection("scanned_problem_records").updateMany(
      { userId: fromUserId },
      { $set: { userId: toUserId } },
    ),
    db.collection("practice_mistake_records").updateMany(
      { userId: fromUserId },
      { $set: { userId: toUserId } },
    ),
  ]);
}
