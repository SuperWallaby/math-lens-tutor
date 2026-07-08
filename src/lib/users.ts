import { randomBytes, randomUUID } from "crypto";

import { getMongoDb } from "./mongodb";
import { reassignUserData, uploadProfileImage, deleteAllUserData } from "./store";
import { ageFromGrade, isValidGrade } from "./grade-options";
import type {
  LinkedStudentSummary,
  OAuthProvider,
  StudentLink,
  User,
  UserRole,
} from "./types";
import type { VerifiedOAuthIdentity } from "./oauth-verify";
import {
  devAccountToUser,
  type DevAccountSpec,
} from "./dev-accounts";

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

export class OAuthAccountExistsError extends Error {
  constructor() {
    super(
      "이미 가입된 계정입니다. 앱을 처음부터 다시 열어 해당 계정으로 로그인해 주세요.",
    );
    this.name = "OAuthAccountExistsError";
  }
}

const OAUTH_DISPLAY_NAME_PLACEHOLDERS = new Set([
  "카카오 사용자",
  "Google 사용자",
  "Apple 사용자",
]);

function maybeRefreshOAuthDisplayName(
  current: string,
  next: string,
): string | null {
  const trimmedNext = next.trim();
  if (!trimmedNext || OAUTH_DISPLAY_NAME_PLACEHOLDERS.has(trimmedNext)) {
    return null;
  }
  if (OAUTH_DISPLAY_NAME_PLACEHOLDERS.has(current.trim())) {
    return trimmedNext;
  }
  return null;
}

export async function upsertOAuthUser(
  identity: VerifiedOAuthIdentity,
  deviceUserId?: string | null,
  options?: { intent?: "signup" | "login" },
): Promise<User> {
  const existing = await findUserByOAuth(
    identity.provider,
    identity.subject,
  );

  if (existing) {
    if (options?.intent === "signup") {
      throw new OAuthAccountExistsError();
    }
    let dirty = false;
    const refreshedName = maybeRefreshOAuthDisplayName(
      existing.displayName,
      identity.displayName,
    );
    if (refreshedName) {
      existing.displayName = refreshedName;
      dirty = true;
    }
    let mergeDevice = false;
    if (deviceUserId && !existing.linkedDeviceIds.includes(deviceUserId)) {
      existing.linkedDeviceIds.push(deviceUserId);
      dirty = true;
      mergeDevice = true;
    }
    if (dirty) {
      await saveUser(existing);
    }
    if (mergeDevice && deviceUserId) {
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

export async function upsertMagicLinkUser(
  email: string,
  deviceUserId?: string | null,
  options?: { intent?: "signup" | "login" },
): Promise<User> {
  const normalized = email.trim().toLowerCase();
  const identity = {
    provider: "email" as const,
    subject: normalized,
    displayName: normalized.split("@")[0] || "우열 사용자",
  };
  const user = await upsertOAuthUser(identity, deviceUserId, options);
  if (!user.email) {
    user.email = normalized;
    await saveUser(user);
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
  options?: { age?: number; grade?: string; organizationName?: string },
): Promise<User> {
  const user = await findUserById(userId);
  if (!user) {
    throw new Error("User not found.");
  }

  const previousRole = user.role;
  if (
    previousRole &&
    previousRole !== role &&
    (previousRole === "parent" || previousRole === "teacher")
  ) {
    await clearAllLinksForUser(userId);
  }

  user.role = role;
  user.profileComplete = true;

  if (typeof options?.age === "number" && options.age >= 8 && options.age <= 99) {
    user.age = Math.round(options.age);
  }

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

export async function resetUserProfileRole(userId: string): Promise<User> {
  const user = await findUserById(userId);
  if (!user) {
    throw new Error("사용자를 찾을 수 없습니다.");
  }

  if (user.role !== "parent" && user.role !== "teacher") {
    throw new Error("역할을 다시 선택할 수 없는 계정입니다.");
  }

  await clearAllLinksForUser(userId);
  user.role = null;
  user.profileComplete = false;
  user.organizationName = undefined;

  return saveUser(user);
}

export async function updateUserProfile(
  userId: string,
  updates: {
    displayName?: string;
    grade?: string;
    organizationName?: string;
  },
): Promise<User> {
  const user = await findUserById(userId);
  if (!user) {
    throw new Error("사용자를 찾을 수 없습니다.");
  }

  if (updates.displayName !== undefined) {
    const name = updates.displayName.trim();
    if (name.length < 1 || name.length > 40) {
      throw new Error("이름은 1~40자로 입력해 주세요.");
    }
    user.displayName = name;
  }

  if (updates.grade !== undefined) {
    if (user.role !== "student") {
      throw new Error("학년은 학생 계정만 수정할 수 있습니다.");
    }
    const grade = updates.grade.trim();
    if (!isValidGrade(grade)) {
      throw new Error("올바른 학년을 선택해 주세요.");
    }
    user.grade = grade;
    user.age = ageFromGrade(grade);
  }

  if (updates.organizationName !== undefined) {
    if (user.role !== "teacher") {
      throw new Error("소속명은 교사 계정만 수정할 수 있습니다.");
    }
    const org = updates.organizationName.trim();
    user.organizationName = org.length > 0 ? org : undefined;
  }

  return saveUser(user);
}

export async function setUserProfileImage(
  userId: string,
  file: File,
): Promise<User> {
  const user = await findUserById(userId);
  if (!user) {
    throw new Error("사용자를 찾을 수 없습니다.");
  }

  const imageUrl = await uploadProfileImage(file, userId);
  if (!imageUrl) {
    throw new Error("프로필 이미지를 저장하지 못했습니다.");
  }

  user.profileImageUrl = imageUrl;
  return saveUser(user);
}

export async function clearAllLinksForUser(userId: string): Promise<void> {
  const store = await requireUsersStore();
  if ("links" in store) {
    store.links = store.links.filter(
      (link) =>
        link.guardianUserId !== userId && link.studentUserId !== userId,
    );
    return;
  }

  await store.collection<StudentLink>("student_links").deleteMany({
    $or: [{ guardianUserId: userId }, { studentUserId: userId }],
  });
}

export async function deleteUserAccount(userId: string): Promise<void> {
  const user = await findUserById(userId);
  if (!user) {
    throw new Error("사용자를 찾을 수 없습니다.");
  }

  await clearAllLinksForUser(userId);
  await deleteAllUserData(userId);

  const store = await requireUsersStore();
  if ("users" in store) {
    store.users = store.users.filter((item) => item.id !== userId);
    return;
  }

  await store.collection<User>("users").deleteOne({ id: userId });
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

function toLinkedStudentSummary(
  student: User,
  link?: Pick<StudentLink, "guardianLabel"> | null,
): LinkedStudentSummary {
  return {
    id: student.id,
    displayName: student.displayName,
    studentCode: student.studentCode!,
    guardianLabel: link?.guardianLabel?.trim() || null,
    profileImageUrl: student.profileImageUrl ?? null,
  };
}

export async function findUserByEmailAndProvider(
  email: string,
  provider: User["oauthProvider"],
): Promise<User | null> {
  const normalized = email.trim().toLowerCase();
  const store = await requireUsersStore();

  if ("users" in store) {
    return (
      store.users.find(
        (user) =>
          user.oauthProvider === provider &&
          user.email?.trim().toLowerCase() === normalized,
      ) ?? null
    );
  }

  return store.collection<User>("users").findOne(
    { oauthProvider: provider, email: normalized },
    { projection: { _id: 0 } },
  );
}

export async function loginDevOAuthUser(params: {
  userId: string;
  provider: User["oauthProvider"];
  deviceUserId?: string | null;
}): Promise<User> {
  const user = await findUserById(params.userId);
  if (!user || user.oauthProvider !== params.provider) {
    throw new Error("개발용 OAuth 계정을 찾을 수 없습니다.");
  }

  if (params.deviceUserId && !user.linkedDeviceIds.includes(params.deviceUserId)) {
    user.linkedDeviceIds.push(params.deviceUserId);
    await saveUser(user);
    await mergeDeviceData(params.deviceUserId, user.id);
  }

  return user;
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
    throw new Error("학생 고유번호를 찾을 수 없습니다. 번호를 다시 확인해 주세요.");
  }

  if (student.id === guardianUserId) {
    throw new Error("본인 계정은 연결할 수 없습니다.");
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
    const savedLink = store.links.find(
      (item) =>
        item.guardianUserId === guardianUserId &&
        item.studentUserId === student.id,
    );
    return toLinkedStudentSummary(student, savedLink);
  } else {
    await store.collection<StudentLink>("student_links").updateOne(
      { guardianUserId, studentUserId: student.id },
      { $setOnInsert: link },
      { upsert: true },
    );
    const savedLink = await store
      .collection<StudentLink>("student_links")
      .findOne({ guardianUserId, studentUserId: student.id });
    return toLinkedStudentSummary(student, savedLink);
  }
}

export async function getLinkedStudents(
  guardianUserId: string,
): Promise<LinkedStudentSummary[]> {
  const store = await requireUsersStore();
  const students: LinkedStudentSummary[] = [];

  if ("links" in store) {
    const links = store.links.filter(
      (link) => link.guardianUserId === guardianUserId,
    );
    for (const link of links) {
      const student = await findUserById(link.studentUserId);
      if (student?.studentCode) {
        students.push(toLinkedStudentSummary(student, link));
      }
    }
    return students;
  }

  const links = await store
    .collection<StudentLink>("student_links")
    .find({ guardianUserId }, { projection: { _id: 0 } })
    .toArray();

  for (const link of links) {
    const student = await findUserById(link.studentUserId);
    if (student?.studentCode) {
      students.push(toLinkedStudentSummary(student, link));
    }
  }

  return students;
}

export async function updateLinkedStudentGuardianLabel(
  guardianUserId: string,
  studentUserId: string,
  guardianLabel: string | null,
): Promise<LinkedStudentSummary> {
  const linked = await isGuardianLinkedToStudent(guardianUserId, studentUserId);
  if (!linked) {
    throw new Error("연결된 학생을 찾을 수 없습니다.");
  }

  const student = await findUserById(studentUserId);
  if (!student?.studentCode) {
    throw new Error("연결된 학생을 찾을 수 없습니다.");
  }

  const label = guardianLabel?.trim() || null;
  const store = await requireUsersStore();

  if ("links" in store) {
    const link = store.links.find(
      (item) =>
        item.guardianUserId === guardianUserId &&
        item.studentUserId === studentUserId,
    );
    if (!link) {
      throw new Error("연결된 학생을 찾을 수 없습니다.");
    }
    link.guardianLabel = label;
    return toLinkedStudentSummary(student, link);
  }

  await store.collection<StudentLink>("student_links").updateOne(
    { guardianUserId, studentUserId },
    { $set: { guardianLabel: label } },
  );
  const savedLink = await store
    .collection<StudentLink>("student_links")
    .findOne({ guardianUserId, studentUserId });
  return toLinkedStudentSummary(student, savedLink);
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

export async function clearStudentLinksForGuardian(
  guardianUserId: string,
): Promise<void> {
  const store = await requireUsersStore();
  if ("links" in store) {
    store.links = store.links.filter(
      (link) => link.guardianUserId !== guardianUserId,
    );
    return;
  }

  await store
    .collection<StudentLink>("student_links")
    .deleteMany({ guardianUserId });
}

export async function resetDevLoginAccount(
  spec: DevAccountSpec,
  deviceUserId?: string | null,
): Promise<User> {
  await clearStudentLinksForGuardian(spec.userId);
  const existing = await findUserById(spec.userId);
  const user = devAccountToUser(spec, existing);

  if (deviceUserId) {
    user.linkedDeviceIds = [...new Set([...user.linkedDeviceIds, deviceUserId])];
  }

  await saveUser(user);

  if (deviceUserId) {
    await mergeDeviceData(deviceUserId, user.id);
  }

  return user;
}

export function publicUser(user: User) {
  return {
    id: user.id,
    role: user.role,
    displayName: user.displayName,
    age: user.age,
    grade: user.grade,
    organizationName: user.organizationName,
    studentCode: user.studentCode,
    profileImageUrl: user.profileImageUrl,
    profileComplete: user.profileComplete,
    oauthProvider: user.oauthProvider,
    email: user.email,
    createdAt: user.createdAt,
  };
}
