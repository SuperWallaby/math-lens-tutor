import { randomUUID } from "crypto";

import { getMongoDb } from "./mongodb";
import type {
  AnalysisJob,
  AnalysisJobType,
  ConceptMasteryEntry,
  DifficultyStats,
  GeneratedProblem,
  TrainingFeedItem,
  UserConceptMastery,
  UserFeedQueue,
} from "./types";

const globalForTrainingFeed = globalThis as typeof globalThis & {
  trainingFeedMemory?: {
    jobs: AnalysisJob[];
    mastery: Map<string, UserConceptMastery>;
    queues: Map<string, UserFeedQueue>;
  };
};

const memory: {
  jobs: AnalysisJob[];
  mastery: Map<string, UserConceptMastery>;
  queues: Map<string, UserFeedQueue>;
} = (globalForTrainingFeed.trainingFeedMemory ??=
  globalForTrainingFeed.trainingFeedMemory = {
    jobs: [],
    mastery: new Map(),
    queues: new Map(),
  });

let indexesEnsured = false;

export async function ensureTrainingFeedIndexes() {
  if (indexesEnsured) return;
  const db = await getMongoDb();
  if (!db) {
    indexesEnsured = true;
    return;
  }

  await Promise.all([
    db.collection<AnalysisJob>("analysis_jobs").createIndex({
      status: 1,
      createdAt: 1,
    }),
    db.collection<AnalysisJob>("analysis_jobs").createIndex(
      { userId: 1, type: 1, status: 1 },
      { name: "analysis_jobs_user_type_status" },
    ),
    db.collection<UserConceptMastery>("user_concept_mastery").createIndex(
      { userId: 1 },
      { unique: true },
    ),
    db.collection<UserFeedQueue>("user_feed_queues").createIndex(
      { userId: 1 },
      { unique: true },
    ),
  ]);

  indexesEnsured = true;
}

function emptyStats(): DifficultyStats {
  return { attempts: 0, correct: 0, incorrect: 0 };
}

export function createEmptyMasteryEntry(concept: string): ConceptMasteryEntry {
  return {
    concept,
    easy: emptyStats(),
    medium: emptyStats(),
    hard: emptyStats(),
    targetDifficulty: "medium",
  };
}

function conceptKey(concept: string): string {
  return concept.trim().toLowerCase();
}

export async function getUserConceptMastery(
  userId: string,
): Promise<UserConceptMastery | null> {
  await ensureTrainingFeedIndexes();
  const db = await getMongoDb();
  if (!db) {
    return memory.mastery.get(userId) ?? null;
  }

  return db
    .collection<UserConceptMastery>("user_concept_mastery")
    .findOne({ userId }, { projection: { _id: 0 } });
}

export async function saveUserConceptMastery(
  doc: UserConceptMastery,
): Promise<void> {
  await ensureTrainingFeedIndexes();
  const db = await getMongoDb();
  if (!db) {
    memory.mastery.set(doc.userId, doc);
    return;
  }

  await db.collection<UserConceptMastery>("user_concept_mastery").replaceOne(
    { userId: doc.userId },
    doc,
    { upsert: true },
  );
}

export async function applyAttemptToMastery(params: {
  userId: string;
  conceptTags: string[];
  difficulty: GeneratedProblem["difficulty"];
  isCorrect: boolean;
}): Promise<void> {
  const concepts = [
    ...new Set(params.conceptTags.map((tag) => tag.trim()).filter(Boolean)),
  ];
  if (concepts.length === 0) return;

  const existing =
    (await getUserConceptMastery(params.userId)) ??
    ({
      userId: params.userId,
      concepts: {},
      updatedAt: new Date().toISOString(),
    } satisfies UserConceptMastery);

  for (const concept of concepts) {
    const key = conceptKey(concept);
    const entry = existing.concepts[key] ?? createEmptyMasteryEntry(concept);
    const bucket = entry[params.difficulty];
    bucket.attempts += 1;
    if (params.isCorrect) bucket.correct += 1;
    else bucket.incorrect += 1;
    entry.targetDifficulty = computeTargetDifficulty(entry);
    existing.concepts[key] = { ...entry, concept };
  }

  existing.updatedAt = new Date().toISOString();
  await saveUserConceptMastery(existing);
}

export function computeTargetDifficulty(
  entry: ConceptMasteryEntry,
): GeneratedProblem["difficulty"] {
  const rate = (stats: DifficultyStats) =>
    stats.attempts > 0 ? stats.correct / stats.attempts : null;

  const easyRate = rate(entry.easy);
  const mediumRate = rate(entry.medium);
  const hardRate = rate(entry.hard);

  if (
    entry.medium.attempts >= 2 &&
    mediumRate !== null &&
    mediumRate >= 0.7 &&
    entry.hard.attempts < 2
  ) {
    return "hard";
  }
  if (
    entry.easy.attempts >= 2 &&
    easyRate !== null &&
    easyRate >= 0.8 &&
    entry.medium.attempts < 3
  ) {
    return "medium";
  }
  if (
    entry.medium.attempts >= 2 &&
    mediumRate !== null &&
    mediumRate < 0.4
  ) {
    return "easy";
  }
  if (entry.hard.attempts >= 1 && entry.hard.correct === 0) {
    return "medium";
  }
  if (entry.easy.attempts >= 1 && easyRate !== null && easyRate < 0.5) {
    return "easy";
  }
  return "medium";
}

export async function getUserFeedQueue(
  userId: string,
): Promise<UserFeedQueue | null> {
  await ensureTrainingFeedIndexes();
  const db = await getMongoDb();
  if (!db) {
    return memory.queues.get(userId) ?? null;
  }

  return db
    .collection<UserFeedQueue>("user_feed_queues")
    .findOne({ userId }, { projection: { _id: 0 } });
}

export async function saveUserFeedQueue(queue: UserFeedQueue): Promise<void> {
  await ensureTrainingFeedIndexes();
  const db = await getMongoDb();
  if (!db) {
    memory.queues.set(queue.userId, queue);
    return;
  }

  await db.collection<UserFeedQueue>("user_feed_queues").replaceOne(
    { userId: queue.userId },
    queue,
    { upsert: true },
  );
}

export async function enqueueAnalysisJob(params: {
  userId: string;
  type: AnalysisJobType;
}): Promise<void> {
  await ensureTrainingFeedIndexes();
  const db = await getMongoDb();

  const pendingFilter = {
    userId: params.userId,
    type: params.type,
    status: { $in: ["pending", "processing"] as AnalysisJob["status"][] },
  };

  if (!db) {
    const exists = memory.jobs.some(
      (job) =>
        job.userId === params.userId &&
        job.type === params.type &&
        (job.status === "pending" || job.status === "processing"),
    );
    if (exists) return;
    memory.jobs.unshift({
      id: randomUUID(),
      userId: params.userId,
      type: params.type,
      status: "pending",
      createdAt: new Date().toISOString(),
      attempts: 0,
    } satisfies AnalysisJob);
    return;
  }

  const existing = await db
    .collection<AnalysisJob>("analysis_jobs")
    .findOne(pendingFilter, { projection: { _id: 1 } });
  if (existing) return;

  const job: AnalysisJob = {
    id: randomUUID(),
    userId: params.userId,
    type: params.type,
    status: "pending",
    createdAt: new Date().toISOString(),
    attempts: 0,
  };

  await db.collection<AnalysisJob>("analysis_jobs").insertOne(job);
}

export async function claimNextAnalysisJob(): Promise<AnalysisJob | null> {
  await ensureTrainingFeedIndexes();
  const db = await getMongoDb();
  const now = new Date().toISOString();

  if (!db) {
    const job = memory.jobs.find((row) => row.status === "pending");
    if (!job) return null;
    job.status = "processing";
    job.startedAt = now;
    job.attempts += 1;
    return { ...job };
  }

  return db.collection<AnalysisJob>("analysis_jobs").findOneAndUpdate(
    { status: "pending" },
    {
      $set: { status: "processing", startedAt: now },
      $inc: { attempts: 1 },
    },
    { sort: { createdAt: 1 }, returnDocument: "after", projection: { _id: 0 } },
  );
}

export async function finishAnalysisJob(params: {
  jobId: string;
  status: "done" | "failed";
  error?: string;
}): Promise<void> {
  await ensureTrainingFeedIndexes();
  const db = await getMongoDb();
  const finishedAt = new Date().toISOString();

  if (!db) {
    const job = memory.jobs.find((row) => row.id === params.jobId);
    if (!job) return;
    job.status = params.status;
    job.finishedAt = finishedAt;
    job.error = params.error;
    return;
  }

  await db.collection<AnalysisJob>("analysis_jobs").updateOne(
    { id: params.jobId },
    {
      $set: {
        status: params.status,
        finishedAt,
        ...(params.error ? { error: params.error } : {}),
      },
    },
  );
}

export async function hasPendingFeedRefresh(userId: string): Promise<boolean> {
  await ensureTrainingFeedIndexes();
  const db = await getMongoDb();
  if (!db) {
    return memory.jobs.some(
      (job) =>
        job.userId === userId &&
        job.type === "refresh_user_feed" &&
        (job.status === "pending" || job.status === "processing"),
    );
  }

  const row = await db.collection<AnalysisJob>("analysis_jobs").findOne(
    {
      userId,
      type: "refresh_user_feed",
      status: { $in: ["pending", "processing"] },
    },
    { projection: { _id: 1 } },
  );
  return Boolean(row);
}

export function buildFeedItemFromBank(params: {
  item: {
    id: string;
    title: string;
    prompt: string;
    difficulty: GeneratedProblem["difficulty"];
    conceptPrimary: string;
  };
  reason: string;
}): TrainingFeedItem {
  return {
    id: randomUUID(),
    bankItemId: params.item.id,
    concept: params.item.conceptPrimary,
    difficulty: params.item.difficulty,
    reason: params.reason,
    title: params.item.title.trim(),
    promptPreview: "",
    problemCount: 1,
  };
}
