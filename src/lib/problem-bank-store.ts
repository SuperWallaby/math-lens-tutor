import { createHash } from "crypto";

import { getMongoDb } from "./mongodb";
import type {
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

export async function insertBankItem(
  item: ProblemBankItem,
): Promise<ProblemBankItem> {
  const store = await requireProblemBankStore();
  if ("bankItems" in store) {
    const existing = store.bankItems.find((i) => i.contentHash === item.contentHash);
    if (existing) return existing;
    store.bankItems.unshift(item);
    return item;
  }

  try {
    await store.collection<ProblemBankItem>("problem_bank_items").insertOne(item);
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
}): Promise<ProblemBankItem[]> {
  const delivered = await getDeliveredBankItemIds(params.userId);
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
    candidates = await store
      .collection<ProblemBankItem>("problem_bank_items")
      .find(
        {
          active: true,
          gradeBand: params.gradeBand,
          id: { $nin: [...delivered] },
        },
        { projection: { _id: 0 } },
      )
      .sort({ deliveryCount: 1, createdAt: -1 })
      .limit(200)
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
      return { item, score: overlap + primaryMatch };
    })
    .filter((row) => row.score > 0)
    .sort((a, b) => {
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
