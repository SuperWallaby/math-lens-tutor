import { getSessionUserId } from "./auth";
import { findUserById, isGuardianLinkedToStudent } from "./users";
import { DEMO_USER_ID } from "./store";

import type { User, UserRole } from "./types";

const DEVICE_ID_HEADER = "x-device-id";
const VIEW_AS_STUDENT_HEADER = "x-view-as-student";
const SAFE_DEVICE_ID = /^[a-zA-Z0-9._:-]{8,128}$/;

export class RequestAuthError extends Error {
  constructor(
    public status: number,
    message: string,
  ) {
    super(message);
    this.name = "RequestAuthError";
  }
}

export type ResolvedActor = {
  authUserId: string;
  actorUserId: string;
  user: User;
  role: UserRole;
  isGuardianView: boolean;
  isGuest: boolean;
};

function buildGuestUser(actorUserId: string): User {
  const deviceRaw = actorUserId.startsWith("device:")
    ? actorUserId.slice("device:".length)
    : actorUserId;

  return {
    id: actorUserId,
    role: "student",
    displayName: "게스트",
    grade: "중1",
    profileComplete: true,
    oauthProvider: "google",
    oauthSubject: `guest:${deviceRaw}`,
    linkedDeviceIds: deviceRaw ? [deviceRaw] : [],
    createdAt: new Date().toISOString(),
  };
}

function resolveGuestActor(request: Request): ResolvedActor {
  const actorUserId = getRequestUserId(request);
  const user = buildGuestUser(actorUserId);

  return {
    authUserId: actorUserId,
    actorUserId,
    user,
    role: "student",
    isGuardianView: false,
    isGuest: true,
  };
}

export function getRequestUserId(request: Request): string {
  const raw = request.headers.get(DEVICE_ID_HEADER)?.trim();
  if (!raw || !SAFE_DEVICE_ID.test(raw)) {
    return DEMO_USER_ID;
  }
  return `device:${raw}`;
}

export function getDeviceUserId(request: Request): string | null {
  const raw = request.headers.get(DEVICE_ID_HEADER)?.trim();
  if (!raw || !SAFE_DEVICE_ID.test(raw)) {
    return null;
  }
  return `device:${raw}`;
}

export async function getAuthenticatedUser(
  request: Request,
): Promise<User> {
  const authUserId = getSessionUserId(request);
  if (!authUserId) {
    throw new RequestAuthError(401, "로그인이 필요합니다. 간편 가입 후 이용해 주세요.");
  }

  const user = await findUserById(authUserId);
  if (!user) {
    throw new RequestAuthError(401, "세션이 만료되었습니다. 다시 가입해 주세요.");
  }

  return user;
}

export async function requireAuthenticatedUser(
  request: Request,
): Promise<User> {
  const user = await getAuthenticatedUser(request);

  if (!user.profileComplete || !user.role) {
    throw new RequestAuthError(
      403,
      "가입을 완료해 주세요. 역할 선택이 필요합니다.",
    );
  }

  return user;
}

export async function resolveActorUserId(
  request: Request,
  options?: { write?: boolean; requireAuth?: boolean },
): Promise<ResolvedActor> {
  const authUserId = getSessionUserId(request);
  if (!authUserId) {
    if (options?.requireAuth) {
      throw new RequestAuthError(
        401,
        "로그인이 필요합니다. 간편 가입 후 이용해 주세요.",
      );
    }
    return resolveGuestActor(request);
  }

  const user = await requireAuthenticatedUser(request);

  if (user.role === "student") {
    return {
      authUserId: user.id,
      actorUserId: user.id,
      user,
      role: user.role,
      isGuardianView: false,
      isGuest: false,
    };
  }

  if (options?.write) {
    throw new RequestAuthError(
      403,
      "학부모·교사 계정은 학생 활동 조회만 가능합니다. 풀이 등록은 학생 계정으로 진행해 주세요.",
    );
  }

  const viewAsStudentId = request.headers
    .get(VIEW_AS_STUDENT_HEADER)
    ?.trim();

  if (!viewAsStudentId) {
    throw new RequestAuthError(
      400,
      "조회할 학생을 선택해 주세요.",
    );
  }

  const linked = await isGuardianLinkedToStudent(user.id, viewAsStudentId);
  if (!linked) {
    throw new RequestAuthError(
      403,
      "연결되지 않은 학생입니다. 학생 고유번호로 먼저 연결해 주세요.",
    );
  }

  const student = await findUserById(viewAsStudentId);
  if (!student || student.role !== "student") {
    throw new RequestAuthError(404, "학생 계정을 찾을 수 없습니다.");
  }

  return {
    authUserId: user.id,
    actorUserId: student.id,
    user,
    role: user.role as UserRole,
    isGuardianView: true,
    isGuest: false,
  };
}

export function authErrorResponse(error: unknown) {
  if (error instanceof RequestAuthError) {
    return Response.json({ error: error.message }, { status: error.status });
  }
  return null;
}
