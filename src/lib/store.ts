import { randomUUID } from "crypto";
import { getMongoDb } from "./mongodb";
import { buildSampleInsight, sampleProblemSet, sampleSubmission } from "./sample";
import type {
  GeneratedProblemSet,
  LearningInsight,
  ProblemAttempt,
  SolutionSubmission,
} from "./types";

type MemoryDb = {
  submissions: SolutionSubmission[];
  problemSets: GeneratedProblemSet[];
  attempts: ProblemAttempt[];
};

const globalForStore = globalThis as typeof globalThis & {
  mathTutorMemoryDb?: MemoryDb;
};

const memoryDb =
  globalForStore.mathTutorMemoryDb ??
  (globalForStore.mathTutorMemoryDb = {
    submissions: [sampleSubmission],
    problemSets: [sampleProblemSet],
    attempts: [],
  });

export const DEMO_USER_ID = "demo-user";

export async function uploadSolutionImage(
  file: File,
  userId: string,
): Promise<string | null> {
  const db = await getMongoDb();
  if (!db) {
    return null;
  }

  const buffer = Buffer.from(await file.arrayBuffer());
  const imageId = randomUUID();
  const mimeType = file.type || "image/jpeg";

  await db.collection("solution_images").insertOne({
    id: imageId,
    userId,
    imageName: file.name,
    mimeType,
    data: buffer.toString("base64"),
    createdAt: new Date().toISOString(),
  });

  return `/api/images/${imageId}`;
}

export async function saveSubmission(
  submission: SolutionSubmission,
): Promise<SolutionSubmission> {
  const db = await getMongoDb();
  if (!db) {
    memoryDb.submissions.unshift(submission);
    return submission;
  }

  await db.collection<SolutionSubmission>("solution_submissions").insertOne(submission);

  return submission;
}

export async function saveProblemSet(
  problemSet: GeneratedProblemSet,
): Promise<GeneratedProblemSet> {
  const db = await getMongoDb();
  if (!db) {
    memoryDb.problemSets.unshift(problemSet);
    return problemSet;
  }

  await db.collection<GeneratedProblemSet>("generated_problem_sets").insertOne(problemSet);

  return problemSet;
}

export async function getSubmission(
  id: string,
): Promise<SolutionSubmission | null> {
  const db = await getMongoDb();
  if (!db) {
    return memoryDb.submissions.find((submission) => submission.id === id) ?? null;
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
      memoryDb.problemSets.find((set) => set.submissionId === submissionId) ?? null
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
    return memoryDb.problemSets.find((set) => set.id === id) ?? null;
  }

  return db
    .collection<GeneratedProblemSet>("generated_problem_sets")
    .findOne({ id }, { projection: { _id: 0 } });
}

export async function saveAttempt(attempt: ProblemAttempt): Promise<ProblemAttempt> {
  const db = await getMongoDb();
  if (!db) {
    memoryDb.attempts.unshift(attempt);
    return attempt;
  }

  await db.collection<ProblemAttempt>("problem_attempts").insertOne(attempt);

  return attempt;
}

export async function getAttempts(userId = DEMO_USER_ID): Promise<ProblemAttempt[]> {
  const db = await getMongoDb();
  if (!db) {
    return memoryDb.attempts.filter((attempt) => attempt.userId === userId);
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
