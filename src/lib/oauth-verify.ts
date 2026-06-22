import { createHash } from "crypto";

import { env, googleClientIds } from "./env";
import type { OAuthProvider } from "./types";

export type VerifiedOAuthIdentity = {
  provider: OAuthProvider;
  subject: string;
  displayName: string;
};

type GoogleTokenInfo = {
  sub?: string;
  aud?: string;
  name?: string;
  email?: string;
};

type AppleIdentityClaims = {
  sub?: string;
  aud?: string;
  iss?: string;
  exp?: number;
};

type KakaoUserResponse = {
  id?: number;
  kakao_account?: {
    profile?: {
      nickname?: string;
    };
  };
};

type AppleJwks = {
  keys?: Array<{
    kid?: string;
    kty?: string;
    n?: string;
    e?: string;
    alg?: string;
    use?: string;
  }>;
};

let appleJwksCache: { fetchedAt: number; keys: AppleJwks["keys"] } | null =
  null;

async function fetchJson<T>(url: string, init?: RequestInit): Promise<T> {
  const response = await fetch(url, init);
  if (!response.ok) {
    throw new Error(`OAuth verification failed (${response.status}).`);
  }
  return (await response.json()) as T;
}

export async function verifyGoogleIdToken(
  idToken: string,
): Promise<VerifiedOAuthIdentity> {
  const info = await fetchJson<GoogleTokenInfo>(
    `https://oauth2.googleapis.com/tokeninfo?id_token=${encodeURIComponent(idToken)}`,
  );

  const allowedAudiences = googleClientIds();
  if (
    allowedAudiences.length > 0 &&
    (!info.aud || !allowedAudiences.includes(info.aud))
  ) {
    throw new Error("Google token audience is not allowed.");
  }

  if (!info.sub) {
    throw new Error("Google token is missing subject.");
  }

  return {
    provider: "google",
    subject: info.sub,
    displayName: info.name?.trim() || info.email?.trim() || "Google 사용자",
  };
}

async function getApplePublicKey(kid: string) {
  const now = Date.now();
  if (!appleJwksCache || now - appleJwksCache.fetchedAt > 60 * 60 * 1000) {
    const jwks = await fetchJson<AppleJwks>(
      "https://appleid.apple.com/auth/keys",
    );
    appleJwksCache = {
      fetchedAt: now,
      keys: jwks.keys ?? [],
    };
  }

  const jwk = appleJwksCache.keys?.find((key) => key.kid === kid);
  if (!jwk?.n || !jwk.e) {
    throw new Error("Apple public key not found.");
  }

  const { createPublicKey } = await import("crypto");
  return createPublicKey({
    key: {
      kty: "RSA",
      n: jwk.n,
      e: jwk.e,
    },
    format: "jwk",
  });
}

function decodeJwtPart(part: string): Record<string, unknown> {
  const padded = part.replace(/-/g, "+").replace(/_/g, "/");
  const padLen = (4 - (padded.length % 4)) % 4;
  const json = Buffer.from(padded + "=".repeat(padLen), "base64").toString(
    "utf8",
  );
  return JSON.parse(json) as Record<string, unknown>;
}

export async function verifyAppleIdentityToken(
  identityToken: string,
): Promise<VerifiedOAuthIdentity> {
  const parts = identityToken.split(".");
  if (parts.length !== 3) {
    throw new Error("Invalid Apple identity token.");
  }

  const header = decodeJwtPart(parts[0]) as { kid?: string; alg?: string };
  const claims = decodeJwtPart(parts[1]) as AppleIdentityClaims;

  if (claims.iss !== "https://appleid.apple.com") {
    throw new Error("Invalid Apple token issuer.");
  }

  const appleClientId = env.appleClientId?.trim();
  if (appleClientId && claims.aud !== appleClientId) {
    throw new Error(
      "Apple 로그인 설정이 올바르지 않습니다. APPLE_CLIENT_ID를 Bundle ID와 맞춰 주세요.",
    );
  }

  if (
    claims.exp &&
    claims.exp < Math.floor(Date.now() / 1000)
  ) {
    throw new Error("Apple token expired.");
  }

  if (!header.kid) {
    throw new Error("Apple token header missing kid.");
  }

  const publicKey = await getApplePublicKey(header.kid);
  const { verify } = await import("crypto");
  const valid = verify(
    "sha256",
    Buffer.from(`${parts[0]}.${parts[1]}`),
    publicKey,
    Buffer.from(
      parts[2].replace(/-/g, "+").replace(/_/g, "/") +
        "=".repeat((4 - (parts[2].length % 4)) % 4),
      "base64",
    ),
  );

  if (!valid) {
    throw new Error("Apple token signature invalid.");
  }

  if (!claims.sub) {
    throw new Error("Apple token is missing subject.");
  }

  return {
    provider: "apple",
    subject: claims.sub,
    displayName: "Apple 사용자",
  };
}

export async function verifyKakaoAccessToken(
  accessToken: string,
): Promise<VerifiedOAuthIdentity> {
  const user = await fetchJson<KakaoUserResponse>(
    "https://kapi.kakao.com/v2/user/me",
    {
      headers: {
        Authorization: `Bearer ${accessToken}`,
        "Content-Type": "application/x-www-form-urlencoded;charset=utf-8",
      },
    },
  );

  if (!user.id) {
    throw new Error("Kakao token is missing subject.");
  }

  const nickname = user.kakao_account?.profile?.nickname?.trim();
  return {
    provider: "kakao",
    subject: String(user.id),
    displayName: nickname || "카카오 사용자",
  };
}

export async function verifyOAuthToken(params: {
  provider: OAuthProvider;
  idToken?: string;
  accessToken?: string;
  displayName?: string;
}): Promise<VerifiedOAuthIdentity> {
  if (params.provider === "google") {
    if (!params.idToken) {
      throw new Error("Google idToken is required.");
    }
    return verifyGoogleIdToken(params.idToken);
  }

  if (params.provider === "apple") {
    if (!params.idToken) {
      throw new Error("Apple identityToken is required.");
    }
    const verified = await verifyAppleIdentityToken(params.idToken);
    if (params.displayName?.trim()) {
      verified.displayName = params.displayName.trim();
    }
    return verified;
  }

  if (params.provider === "kakao") {
    if (!params.accessToken) {
      throw new Error("Kakao accessToken is required.");
    }
    return verifyKakaoAccessToken(params.accessToken);
  }

  throw new Error("Unsupported OAuth provider.");
}

export function oauthSubjectHash(provider: OAuthProvider, subject: string) {
  return createHash("sha256")
    .update(`${provider}:${subject}`)
    .digest("hex")
    .slice(0, 12);
}
