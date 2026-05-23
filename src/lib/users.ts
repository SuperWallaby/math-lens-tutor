import { randomBytes, randomUUID } from "crypto";

import { getMongoDb } from "./mongodb";
import { reassignUserData } from "./store";
import type {
  LinkedStudentSummary,
  OAuthProvider,
  StudentLink,
  User,
  UserRole,
} from "./types";
import type { VerifiedOAuthIdentity } from "./oauth-verify";

type MemoryUsersDb = {
  users: User[];
  links: StudentLink[];
};

const globalForUsers = globalThis as typeof globalThis & {
  mathTutorUsersDb?: MemoryUsersDb;
};

const memoryUsersDb =
  globalForUsers.mathTutorUsersDb ??
  (globalForUsers.mathTutorUsersDb = {
    users: [],
    links: [],
  });

const STUDENT_CODE_CHARS = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";

function generateStudentCode(): string {
  let suffix = "";
  for (let i = 0; i < 6; i += 1) {
    suffix += STUDENT_CODE_CHARS[
      randomBytes(1)[0] % STUDENT_CODE_CHARS.length
    ];
  }
  return `WY-${suffix}`;
}

async function ensureUserIndexes() {
  const db = await getMongoDb();
  if (!db) {
    return;
  }

  await db.collection<User>("users").createIndex(
    { oauthProvider: 1, oauthSubject: 1 },
    { unique: true },
  );
  await db.collection<User>("users").createIndex(
    { studentCode: 1 },
    { unique: true, sparse: true },
  );
  await db.collection<StudentLink>("student_links").createIndex(
    { guardianUserId: 1, studentUserId: 1 },
    { unique: true },
  );
}

export async function requireUsersStore() {
  const db = await getMongoDb();
  if (!db) {
    return memoryUsersDb;
  }
  await ensureUserIndexes();
  return db;
}

export async function findUserById(userId: string): Promise<User | null> {
  const store = await requireUsersStore();
  if ("users" in store) {
    return store.users.find((user) => user.id === userId) ?? null;
  }

  return store
    .collection<User>("users")
    .findOne({ id: userId }, { projection: { _id: 0 } });
}

export async function findUserByOAuth(
  provider: OAuthProvider,
  subject: string,
): Promise<User | null> {
  const store = await requireUsersStore();
  if ("users" in store) {
    return (
      store.users.find(
        (user) =>
          user.oauthProvider === provider && user.oauthSubject === subject,
      ) ?? null
    );
  }

  return store
    .collection<User>("users")
    .findOne({ oauthProvider: provider, oauthSubject: subject }, { projection: { _id: 0 } });
}

async function isStudentCodeTaken(code: string): Promise<boolean> {
  const store = await requireUsersStore();
  if ("users" in store) {
    return store.users.some((user) => user.studentCode === code);
  }

  const existing = await store
    .collection<User>("users")
    .findOne({ studentCode: code }, { projection: { _id: 1 } });
  return Boolean(existing);
}

async function createUniqueStudentCode(): Promise<string> {
  for (let attempt = 0; attempt < 12; attempt += 1) {
    const code = generateStudentCode();
    if (!(await isStudentCodeTaken(code))) {
      return code;
    }
  }
  throw new Error("Failed to generate unique student code.");
}

export async function upsertOAuthUser(
  identity: VerifiedOAuthIdentity,
  deviceUserId?: string | null,
): Promise<User> {
  const existing = await findUserByOAuth(
    identity.provider,
    identity.subject,
  );

  if (existing) {
    if (deviceUserId && !existing.linkedDeviceIds.includes(deviceUserId)) {
      existing.linkedDeviceIds.push(deviceUserId);
      await saveUser(existing);
      await mergeDeviceData(deviceUserId, existing.id);
    }
    return existing;
  }

  const user: User = {
    id: randomUUID(),
    role: null,
    displayName: identity.displayName,
    oauthProvider: identity.provider,
    oauthSubject: identity.subject,
    linkedDeviceIds: deviceUserId ? [deviceUserId] : [],
    profileComplete: false,
    createdAt: new Date().toISOString(),
  };

  await saveUser(user);

  if (deviceUserId) {
    await mergeDeviceData(deviceUserId, user.id);
  }

  return user;
}

async function saveUser(user: User): Promise<User> {
  const store = await requireUsersStore();
  if ("users" in store) {
    const index = store.users.findIndex((item) => item.id === user.id);
    if (index >= 0) {
      store.users[index] = user;
    } else {
      store.users.unshift(user);
    }
    return user;
  }

  await store.collection<User>("users").updateOne(
    { id: user.id },
    { $set: user },
    { upsert: true },
  );
  return user;
}

export async function completeUserProfile(
  userId: string,
  role: UserRole,
  options?: { grade?: string; organizationName?: string },
): Promise<User> {
  const user = await findUserById(userId);
  if (!user) {
    throw new Error("User not found.");
  }

  user.role = role;
  user.profileComplete = true;

  if (role === "student") {
    if (!user.studentCode) {
      user.studentCode = await createUniqueStudentCode();
    }
    if (options?.grade?.trim()) {
      user.grade = options.grade.trim();
    }
  }

  if (role === "teacher" && options?.organizationName?.trim()) {
    user.organizationName = options.organizationName.trim();
  }

  return saveUser(user);
}

export async function findUserByStudentCode(
  studentCode: string,
): Promise<User | null> {
  const normalized = studentCode.trim().toUpperCase();
  const store = await requireUsersStore();
  if ("users" in store) {
    return (
      store.users.find(
        (user) => user.studentCode?.toUpperCase() === normalized,
      ) ?? null
    );
  }

  return store
    .collection<User>("users")
    .findOne({ studentCode: normalized }, { projection: { _id: 0 } });
}

export async function linkStudentToGuardian(
  guardianUserId: string,
  studentCode: string,
): Promise<LinkedStudentSummary> {
  const guardian = await findUserById(guardianUserId);
  if (!guardian?.role || guardian.role === "student") {
    throw new Error("Only parent or teacher accounts can link students.");
  }

  const student = await findUserByStudentCode(studentCode);
  if (!student || student.role !== "student" || !student.studentCode) {
    throw new Error("Student code not found.");
  }

  if (student.id === guardianUserId) {
    throw new Error("You cannot link your own account.");
  }

  const store = await requireUsersStore();
  const link: StudentLink = {
    id: randomUUID(),
    guardianUserId,
    studentUserId: student.id,
    createdAt: new Date().toISOString(),
  };

  if ("links" in store) {
    const exists = store.links.some(
      (item) =>
        item.guardianUserId === guardianUserId &&
        item.studentUserId === student.id,
    );
    if (!exists) {
      store.links.unshift(link);
    }
  } else {
    await store.collection<StudentLink>("student_links").updateOne(
      { guardianUserId, studentUserId: student.id },
      { $setOnInsert: link },
      { upsert: true },
    );
  }

  return {
    id: student.id,
    displayName: student.displayName,
    studentCode: student.studentCode,
  };
}

export async function getLinkedStudents(
  guardianUserId: string,
): Promise<LinkedStudentSummary[]> {
  const store = await requireUsersStore();
  let studentIds: string[] = [];

  if ("links" in store) {
    studentIds = store.links
      .filter((link) => link.guardianUserId === guardianUserId)
      .map((link) => link.studentUserId);
  } else {
    const links = await store
      .collection<StudentLink>("student_links")
      .find({ guardianUserId }, { projection: { _id: 0 } })
      .toArray();
    studentIds = links.map((link) => link.studentUserId);
  }

  const students: LinkedStudentSummary[] = [];
  for (const studentId of studentIds) {
    const student = await findUserById(studentId);
    if (student?.studentCode) {
      students.push({
        id: student.id,
        displayName: student.displayName,
        studentCode: student.studentCode,
      });
    }
  }

  return students;
}

export async function isGuardianLinkedToStudent(
  guardianUserId: string,
  studentUserId: string,
): Promise<boolean> {
  const store = await requireUsersStore();
  if ("links" in store) {
    return store.links.some(
      (link) =>
        link.guardianUserId === guardianUserId &&
        link.studentUserId === studentUserId,
    );
  }

  const link = await store.collection<StudentLink>("student_links").findOne(
    { guardianUserId, studentUserId },
    { projection: { _id: 1 } },
  );
  return Boolean(link);
}

export async function mergeDeviceData(
  deviceUserId: string,
  userId: string,
): Promise<void> {
  if (!deviceUserId.startsWith("device:")) {
    return;
  }
  await reassignUserData(deviceUserId, userId);
}

export function publicUser(user: User) {
  return {
    id: user.id,
    role: user.role,
    displayName: user.displayName,
    grade: user.grade,
    organizationName: user.organizationName,
    studentCode: user.studentCode,
    profileComplete: user.profileComplete,
    oauthProvider: user.oauthProvider,
    createdAt: user.createdAt,
  };
}
