import { randomUUID } from "crypto";
import { getActiveDbVariant } from "./db-variant";
import { getMongoDb } from "./mongodb";
import {
  buildR2ObjectKey,
  deleteR2ObjectsWithPrefix,
  isR2Configured,
  publicUrlForR2Key,
  uploadToR2,
  type StoredImageKind,
} from "./object-storage";
import { reassignProblemBankUserData } from "./problem-bank-store";
import { buildSampleInsight, sampleProblemSet, sampleSubmission } from "./sample";
import type {
  GeneratedProblemSet,
  LearningInsight,
  ProblemAttempt,
  SolutionSubmission,
} from "./types";
import { prepareGeneratedProblemSet } from "./visualization-bake";
import { scheduleProblemSetVisualizationBakeIfNeeded } from "./visualization-async";
import {
  optimizeSolutionImageVariants,
  solutionImageThumbR2KeyFromR2Key,
} from "./solution-image";

type MemoryDb = {
  submissions: SolutionSubmission[];
  problemSets: GeneratedProblemSet[];
  attempts: ProblemAttempt[];
};

const globalForStore = globalThis as typeof globalThis & {
  mathTutorMemoryDb?: MemoryDb;
  mathTutorMemoryDbLite?: MemoryDb;
};

function createEmptyMemoryDb(): MemoryDb {
  return {
    submissions: [sampleSubmission],
    problemSets: [sampleProblemSet],
    attempts: [],
  };
}

const memoryDbFull =
  globalForStore.mathTutorMemoryDb ??
  (globalForStore.mathTutorMemoryDb = createEmptyMemoryDb());

const memoryDbLite =
  globalForStore.mathTutorMemoryDbLite ??
  (globalForStore.mathTutorMemoryDbLite = createEmptyMemoryDb());

function activeMemoryDb(): MemoryDb {
  return getActiveDbVariant() === "lite" ? memoryDbLite : memoryDbFull;
}

export const DEMO_USER_ID = "demo-user";

async function persistUploadedImage(options: {
  file: File;
  userId: string;
  kind: StoredImageKind;
  buffer: Buffer;
}): Promise<string | null> {
  const db = await getMongoDb();
  if (!db) {
    return null;
  }

  const imageId = randomUUID();
  const createdAt = new Date().toISOString();
  const imageName =
    options.file.name ||
    (options.kind === "profile" ? "profile.jpg" : "upload.jpg");

  let body = options.buffer;
  let thumbBody: Buffer | null = null;
  let mimeType = options.file.type || "image/jpeg";

  if (options.kind === "solution") {
    const optimized = await optimizeSolutionImageVariants(options.buffer);
    body = optimized.display;
    thumbBody = optimized.thumb;
    mimeType = "image/webp";
  }

  if (isR2Configured()) {
    const r2Key = buildR2ObjectKey(
      options.userId,
      options.kind,
      imageId,
      mimeType,
    );
    const uploads = [
      uploadToR2({
        key: r2Key,
        body,
        contentType: mimeType,
        cacheControl: "private, max-age=31536000",
      }),
    ];
    const thumbR2Key =
      thumbBody != null ? solutionImageThumbR2KeyFromR2Key(r2Key) : null;
    if (thumbBody && thumbR2Key) {
      uploads.push(
        uploadToR2({
          key: thumbR2Key,
          body: thumbBody,
          contentType: "image/webp",
          cacheControl: "private, max-age=31536000",
        }),
      );
    }
    await Promise.all(uploads);
    await db.collection("solution_images").insertOne({
      id: imageId,
      userId: options.userId,
      imageName,
      mimeType,
      kind: options.kind,
      storage: "r2",
      r2Key,
      ...(thumbR2Key ? { thumbR2Key } : {}),
      createdAt,
    });
    return publicUrlForR2Key(r2Key) ?? `/api/images/${imageId}`;
  }

  await db.collection("solution_images").insertOne({
    id: imageId,
    userId: options.userId,
    imageName,
    mimeType,
    kind: options.kind,
    storage: "mongo",
    data: body.toString("base64"),
    ...(thumbBody
      ? { thumbMimeType: "image/webp", thumbData: thumbBody.toString("base64") }
      : {}),
    createdAt,
  });

  return `/api/images/${imageId}`;
}

export async function uploadSolutionImage(
  file: File,
  userId: string,
): Promise<string | null> {
  const buffer = Buffer.from(await file.arrayBuffer());
  return persistUploadedImage({
    file,
    userId,
    kind: "solution",
    buffer,
  });
}

export async function uploadProfileImage(
  file: File,
  userId: string,
): Promise<string | null> {
  const buffer = Buffer.from(await file.arrayBuffer());
  if (buffer.byteLength > 2 * 1024 * 1024) {
    throw new Error("프로필 이미지는 2MB 이하만 업로드할 수 있습니다.");
  }

  return persistUploadedImage({
    file,
    userId,
    kind: "profile",
    buffer,
  });
}

export async function deleteAllUserData(userId: string): Promise<void> {
  const db = await getMongoDb();
  if (!db) {
    const submissionIds = new Set(
      activeMemoryDb().submissions
        .filter((item) => item.userId === userId)
        .map((item) => item.id),
    );
    activeMemoryDb().submissions = activeMemoryDb().submissions.filter(
      (item) => item.userId !== userId,
    );
    activeMemoryDb().attempts = activeMemoryDb().attempts.filter(
      (item) => item.userId !== userId,
    );
    activeMemoryDb().problemSets = activeMemoryDb().problemSets.filter(
      (set) => !submissionIds.has(set.submissionId),
    );
    return;
  }

  const submissions = await db
    .collection<SolutionSubmission>("solution_submissions")
    .find({ userId }, { projection: { id: 1, _id: 0 } })
    .toArray();
  const submissionIds = submissions.map((item) => item.id);

  if (isR2Configured()) {
    await deleteR2ObjectsWithPrefix(`${userId}/`);
  }

  await Promise.all([
    db.collection("solution_images").deleteMany({ userId }),
    db.collection("solution_submissions").deleteMany({ userId }),
    db.collection("problem_attempts").deleteMany({ userId }),
    submissionIds.length > 0
      ? db.collection("generated_problem_sets").deleteMany({
          submissionId: { $in: submissionIds },
        })
      : Promise.resolve(),
    db.collection("user_problem_deliveries").deleteMany({ userId }),
    db.collection("scanned_problem_records").deleteMany({ userId }),
    db.collection("practice_mistake_records").deleteMany({ userId }),
  ]);
}

export async function saveSubmission(
  submission: SolutionSubmission,
): Promise<SolutionSubmission> {
  const db = await getMongoDb();
  if (!db) {
    activeMemoryDb().submissions.unshift(submission);
    return submission;
  }

  await db.collection<SolutionSubmission>("solution_submissions").insertOne(submission);

  return submission;
}

export async function saveProblemSet(
  problemSet: GeneratedProblemSet,
): Promise<GeneratedProblemSet> {
  const prepared = prepareGeneratedProblemSet(problemSet);
  const db = await getMongoDb();
  if (!db) {
    activeMemoryDb().problemSets.unshift(prepared);
    scheduleProblemSetVisualizationBakeIfNeeded(prepared);
    return prepared;
  }

  await db.collection<GeneratedProblemSet>("generated_problem_sets").insertOne(prepared);
  scheduleProblemSetVisualizationBakeIfNeeded(prepared);

  return prepared;
}

export async function getSubmission(
  id: string,
): Promise<SolutionSubmission | null> {
  const db = await getMongoDb();
  if (!db) {
    return activeMemoryDb().submissions.find((submission) => submission.id === id) ?? null;
  }

  return db
    .collection<SolutionSubmission>("solution_submissions")
    .findOne({ id }, { projection: { _id: 0 } });
}

export async function getProblemSetBySubmission(
  submissionId: string,
): Promise<GeneratedProblemSet | null> {
  const db = await getMongoDb();
  if (!db) {
    return (
      activeMemoryDb().problemSets.find((set) => set.submissionId === submissionId) ?? null
    );
  }

  return db
    .collection<GeneratedProblemSet>("generated_problem_sets")
    .findOne({ submissionId }, { projection: { _id: 0 } });
}

export async function getProblemSet(
  id: string,
): Promise<GeneratedProblemSet | null> {
  const db = await getMongoDb();
  if (!db) {
    return activeMemoryDb().problemSets.find((set) => set.id === id) ?? null;
  }

  return db
    .collection<GeneratedProblemSet>("generated_problem_sets")
    .findOne({ id }, { projection: { _id: 0 } });
}

export async function getLatestProblemSetWithSubmissionPrefix(
  submissionIdPrefix: string,
): Promise<GeneratedProblemSet | null> {
  const db = await getMongoDb();
  if (!db) {
    return (
      activeMemoryDb().problemSets.find((set) =>
        set.submissionId.startsWith(submissionIdPrefix),
      ) ?? null
    );
  }

  return db
    .collection<GeneratedProblemSet>("generated_problem_sets")
    .findOne(
      { submissionId: { $regex: `^${submissionIdPrefix.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")}` } },
      { projection: { _id: 0 }, sort: { _id: -1 } },
    );
}

export async function updateProblemSet(
  problemSet: GeneratedProblemSet,
): Promise<GeneratedProblemSet> {
  const db = await getMongoDb();
  if (!db) {
    const index = activeMemoryDb().problemSets.findIndex((set) => set.id === problemSet.id);
    if (index >= 0) {
      activeMemoryDb().problemSets[index] = problemSet;
    } else {
      activeMemoryDb().problemSets.unshift(problemSet);
    }
    return problemSet;
  }

  await db.collection<GeneratedProblemSet>("generated_problem_sets").updateOne(
    { id: problemSet.id },
    { $set: problemSet },
    { upsert: true },
  );

  return problemSet;
}

export async function saveAttempt(attempt: ProblemAttempt): Promise<ProblemAttempt> {
  const db = await getMongoDb();
  if (!db) {
    activeMemoryDb().attempts.unshift(attempt);
    return attempt;
  }

  await db.collection<ProblemAttempt>("problem_attempts").insertOne(attempt);

  return attempt;
}

export async function getAttempts(userId = DEMO_USER_ID): Promise<ProblemAttempt[]> {
  const db = await getMongoDb();
  if (!db) {
    return activeMemoryDb().attempts.filter((attempt) => attempt.userId === userId);
  }

  return db
    .collection<ProblemAttempt>("problem_attempts")
    .find({ userId }, { projection: { _id: 0 } })
    .sort({ createdAt: -1 })
    .toArray();
}

export async function getLearningInsight(
  userId = DEMO_USER_ID,
): Promise<LearningInsight> {
  const attempts = await getAttempts(userId);
  return buildSampleInsight(attempts);
}

export async function reassignUserData(
  fromUserId: string,
  toUserId: string,
): Promise<void> {
  const db = await getMongoDb();
  if (db) {
    await Promise.all([
      db.collection("solution_images").updateMany(
        { userId: fromUserId },
        { $set: { userId: toUserId } },
      ),
      db.collection("solution_submissions").updateMany(
        { userId: fromUserId },
        { $set: { userId: toUserId } },
      ),
      db.collection("problem_attempts").updateMany(
        { userId: fromUserId },
        { $set: { userId: toUserId } },
      ),
      reassignProblemBankUserData(fromUserId, toUserId),
    ]);
    return;
  }

  await reassignProblemBankUserData(fromUserId, toUserId);

  for (const submission of activeMemoryDb().submissions) {
    if (submission.userId === fromUserId) {
      submission.userId = toUserId;
    }
  }
  for (const attempt of activeMemoryDb().attempts) {
    if (attempt.userId === fromUserId) {
      attempt.userId = toUserId;
    }
  }
}

export async function getSubmissionsByUserId(
  userId: string,
  limit = 20,
): Promise<SolutionSubmission[]> {
  const db = await getMongoDb();
  if (!db) {
    return activeMemoryDb().submissions
      .filter((submission) => submission.userId === userId)
      .slice(0, limit);
  }

  return db
    .collection<SolutionSubmission>("solution_submissions")
    .find({ userId }, { projection: { _id: 0 } })
    .sort({ createdAt: -1 })
    .limit(limit)
    .toArray();
}

export async function getLatestProblemSetForUser(
  userId: string,
): Promise<GeneratedProblemSet | null> {
  const submissions = await getSubmissionsByUserId(userId, 1);
  if (submissions.length === 0) return null;
  return getProblemSetBySubmission(submissions[0].id);
}
