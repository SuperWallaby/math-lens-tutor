import type { OAuthProvider } from "./types";

export type DevOAuthLoginSpec = {
  id: string;
  label: string;
  email: string;
  provider: Extract<OAuthProvider, "kakao" | "apple">;
  /** DB users.id — OAuth 계정은 email 필드가 비어 있는 경우가 많음 */
  userId?: string;
};

function envUserId(key: string): string | undefined {
  const value = process.env[key]?.trim();
  return value || undefined;
}

/** 로컬 개발 — 카카오/Apple OAuth 계정 즉시 로그인 (userId는 .env.local 로 덮어쓰기 가능) */
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
