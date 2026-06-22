import type { User } from "./types";

export type DevAccountSpec = {
  id: string;
  label: string;
  displayName: string;
  userId: string;
  oauthSubject: string;
};

/** 로컬 개발용 — 역할·프로필 미설정 빈 계정 */
export const DEV_ACCOUNTS: DevAccountSpec[] = [
  {
    id: "empty-1",
    label: "빈 계정 · 민준",
    displayName: "Dev · 민준",
    userId: "00000000-0000-4000-a000-dev00000001",
    oauthSubject: "dev:empty-1",
  },
  {
    id: "empty-2",
    label: "빈 계정 · 서연",
    displayName: "Dev · 서연",
    userId: "00000000-0000-4000-a000-dev00000002",
    oauthSubject: "dev:empty-2",
  },
  {
    id: "empty-3",
    label: "빈 계정 · 준호",
    displayName: "Dev · 준호",
    userId: "00000000-0000-4000-a000-dev00000003",
    oauthSubject: "dev:empty-3",
  },
  {
    id: "empty-4",
    label: "빈 계정 · 지우",
    displayName: "Dev · 지우",
    userId: "00000000-0000-4000-a000-dev00000004",
    oauthSubject: "dev:empty-4",
  },
  {
    id: "empty-5",
    label: "빈 계정 · 하은",
    displayName: "Dev · 하은",
    userId: "00000000-0000-4000-a000-dev00000005",
    oauthSubject: "dev:empty-5",
  },
];

export function findDevAccount(accountId: string): DevAccountSpec | null {
  return DEV_ACCOUNTS.find((account) => account.id === accountId) ?? null;
}

export function devAccountToUser(
  spec: DevAccountSpec,
  existing?: User | null,
): User {
  return {
    id: spec.userId,
    role: null,
    displayName: spec.displayName,
    oauthProvider: "google",
    oauthSubject: spec.oauthSubject,
    linkedDeviceIds: existing?.linkedDeviceIds ?? [],
    profileComplete: false,
    createdAt: existing?.createdAt ?? new Date().toISOString(),
  };
}
