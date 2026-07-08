import type { OAuthProvider } from "./types";
import { findUserByEmailAndProvider, findUserById } from "./users";

export type DevOAuthLoginSpec = {
  id: string;
  label: string;
  email: string;
  provider: Extract<OAuthProvider, "kakao" | "google" | "apple">;
  /** DB users.id — OAuth 계정은 email 필드가 비어 있는 경우가 많음 */
  userId?: string;
};

function envUserId(key: string): string | undefined {
  const value = process.env[key]?.trim();
  return value || undefined;
}

/** 로컬 개발 — OAuth 테스트 계정 (로그인·탈퇴·데이터 삭제) */
export function getDevOAuthLoginAccounts(): DevOAuthLoginSpec[] {
  return [
    {
      id: "kakao-crawl123",
      label: "카카오 · crawl123@naver.com",
      email: "crawl123@naver.com",
      provider: "kakao",
      userId:
        envUserId("DEV_OAUTH_KAKAO_CRAWL123_USER_ID") ??
        "178431c6-fc65-4ee2-840c-faa80205b571",
    },
    {
      id: "google-colton",
      label: "Google · colton950901@gmail.com",
      email: "colton950901@gmail.com",
      provider: "google",
      userId: envUserId("DEV_OAUTH_GOOGLE_COLTON_USER_ID"),
    },
    {
      id: "apple-crawl123",
      label: "Apple · crawl123@naver.com",
      email: "crawl123@naver.com",
      provider: "apple",
      userId:
        envUserId("DEV_OAUTH_APPLE_CRAWL123_USER_ID") ??
        "00a21368-987a-4a50-8a66-9840701b5d4a",
    },
  ];
}

export function findDevOAuthLoginAccount(
  accountId: string,
): DevOAuthLoginSpec | null {
  return getDevOAuthLoginAccounts().find((item) => item.id === accountId) ?? null;
}

/** userId env → 이메일+provider → userId 존재 확인 순으로 계정 조회 */
export async function resolveDevOAuthAccountUserId(
  spec: DevOAuthLoginSpec,
): Promise<string | null> {
  if (spec.userId) {
    const byId = await findUserById(spec.userId);
    if (byId && byId.oauthProvider === spec.provider) {
      return byId.id;
    }
  }

  const byEmail = await findUserByEmailAndProvider(spec.email, spec.provider);
  if (byEmail) {
    return byEmail.id;
  }

  return spec.userId ?? null;
}
