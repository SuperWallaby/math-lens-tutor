import { buildLearningProfile } from "./learning-profile";
import { getMongoDb } from "./mongodb";
import { enqueueAnalysisJob } from "./training-feed-store";
import type { LearningProfile } from "./types";
import { findUserById } from "./users";

export type UserLearningSnapshotDoc = {
  userId: string;
  grade: string;
  profile: LearningProfile;
  updatedAt: string;
};

const COLLECTION = "user_learning_snapshots";
/** 6h — stale이면 read는 캐시 반환 + 백그라운드 갱신 */
export const PROFILE_SNAPSHOT_STALE_MS = 6 * 60 * 60 * 1000;

const memorySnapshots = new Map<string, UserLearningSnapshotDoc>();
const refreshInflight = new Map<string, Promise<LearningProfile>>();
let indexesEnsured = false;

async function ensureSnapshotIndexes() {
  if (indexesEnsured) return;
  const db = await getMongoDb();
  if (!db) {
    indexesEnsured = true;
    return;
  }
  await db.collection(COLLECTION).createIndex({ userId: 1 }, { unique: true });
  indexesEnsured = true;
}

async function resolveGrade(
  userId: string,
  grade?: string | null,
): Promise<string> {
  const trimmed = grade?.trim();
  if (trimmed) return trimmed;
  const user = await findUserById(userId);
  return user?.grade?.trim() || "중1";
}

async function persistSnapshot(doc: UserLearningSnapshotDoc): Promise<void> {
  memorySnapshots.set(doc.userId, doc);
  await ensureSnapshotIndexes();
  const db = await getMongoDb();
  if (!db) return;

  await db.collection<UserLearningSnapshotDoc>(COLLECTION).replaceOne(
    { userId: doc.userId },
    doc,
    { upsert: true },
  );
}

async function loadSnapshotDoc(
  userId: string,
): Promise<UserLearningSnapshotDoc | null> {
  const mem = memorySnapshots.get(userId);
  if (mem) return mem;

  await ensureSnapshotIndexes();
  const db = await getMongoDb();
  if (!db) return null;

  const doc = await db
    .collection<UserLearningSnapshotDoc>(COLLECTION)
    .findOne({ userId }, { projection: { _id: 0 } });
  if (doc) memorySnapshots.set(userId, doc);
  return doc;
}

export async function getCachedLearningProfile(
  userId: string,
  grade: string,
): Promise<LearningProfile | null> {
  const doc = await loadSnapshotDoc(userId);
  if (!doc || doc.grade !== grade) return null;
  return doc.profile;
}

function isSnapshotStale(updatedAt: string): boolean {
  const age = Date.now() - Date.parse(updatedAt);
  return !Number.isFinite(age) || age < 0 || age > PROFILE_SNAPSHOT_STALE_MS;
}

/** 캐시 hit → 즉시 반환. miss → 1회 빌드 후 저장. stale → 캐시 + 백그라운드 갱신. */
export async function getLearningProfileForUser(
  userId: string,
  grade?: string | null,
): Promise<LearningProfile> {
  const resolvedGrade = await resolveGrade(userId, grade);
  const doc = await loadSnapshotDoc(userId);

  if (doc && doc.grade === resolvedGrade) {
    if (isSnapshotStale(doc.updatedAt)) {
      void scheduleLearningProfileRefresh(userId);
    }
    return doc.profile;
  }

  return refreshLearningProfileSnapshot(userId, resolvedGrade);
}

export async function refreshLearningProfileSnapshot(
  userId: string,
  grade?: string | null,
): Promise<LearningProfile> {
  const existing = refreshInflight.get(userId);
  if (existing) return existing;

  const promise = (async () => {
    const resolvedGrade = await resolveGrade(userId, grade);
    const profile = await buildLearningProfile(userId, resolvedGrade);
    await persistSnapshot({
      userId,
      grade: resolvedGrade,
      profile,
      updatedAt: new Date().toISOString(),
    });
    return profile;
  })();

  refreshInflight.set(userId, promise);
  try {
    return await promise;
  } finally {
    refreshInflight.delete(userId);
  }
}

/** write 직후 — read-your-writes용 동기 갱신 */
export async function refreshLearningProfileAfterWrite(
  userId: string,
  grade?: string | null,
): Promise<LearningProfile> {
  return refreshLearningProfileSnapshot(userId, grade);
}

/** v100 worker / stale 백그라운드 — analysis_jobs 큐에 넣음 */
export async function scheduleLearningProfileRefresh(
  userId: string,
): Promise<void> {
  await enqueueAnalysisJob({ userId, type: "refresh_user_profile" });
}

export async function invalidateLearningProfileSnapshot(
  userId: string,
): Promise<void> {
  memorySnapshots.delete(userId);
  await ensureSnapshotIndexes();
  const db = await getMongoDb();
  if (!db) return;
  await db.collection(COLLECTION).deleteOne({ userId });
}
