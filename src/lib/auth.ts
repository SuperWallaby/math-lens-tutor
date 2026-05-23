import { createHmac, timingSafeEqual } from "crypto";

import { env } from "./env";
import type { AuthSessionPayload } from "./types";

const JWT_TTL_SECONDS = 60 * 60 * 24 * 30;

function base64UrlEncode(input: string | Buffer): string {
  const buf = typeof input === "string" ? Buffer.from(input, "utf8") : input;
  return buf
    .toString("base64")
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/g, "");
}

function base64UrlDecode(input: string): string {
  const padded = input.replace(/-/g, "+").replace(/_/g, "/");
  const padLen = (4 - (padded.length % 4)) % 4;
  return Buffer.from(padded + "=".repeat(padLen), "base64").toString("utf8");
}

function getJwtSecret(): string {
  const secret = env.jwtSecret?.trim();
  if (!secret) {
    throw new Error("JWT_SECRET is not configured.");
  }
  return secret;
}

export function signSessionToken(payload: AuthSessionPayload): string {
  const header = base64UrlEncode(JSON.stringify({ alg: "HS256", typ: "JWT" }));
  const now = Math.floor(Date.now() / 1000);
  const body = base64UrlEncode(
    JSON.stringify({
      ...payload,
      iat: now,
      exp: now + JWT_TTL_SECONDS,
    }),
  );
  const signature = createHmac("sha256", getJwtSecret())
    .update(`${header}.${body}`)
    .digest();
  return `${header}.${body}.${base64UrlEncode(signature)}`;
}

export function verifySessionToken(token: string): AuthSessionPayload | null {
  try {
    const secret = getJwtSecret();
    const parts = token.split(".");
    if (parts.length !== 3) {
      return null;
    }

    const [header, body, signature] = parts;
    const expected = createHmac("sha256", secret)
      .update(`${header}.${body}`)
      .digest();
    const actual = Buffer.from(
      signature.replace(/-/g, "+").replace(/_/g, "/") +
        "=".repeat((4 - (signature.length % 4)) % 4),
      "base64",
    );

    if (
      expected.length !== actual.length ||
      !timingSafeEqual(expected, actual)
    ) {
      return null;
    }

    const payload = JSON.parse(base64UrlDecode(body)) as AuthSessionPayload & {
      exp?: number;
    };
    if (!payload.userId || typeof payload.userId !== "string") {
      return null;
    }
    if (payload.exp && payload.exp < Math.floor(Date.now() / 1000)) {
      return null;
    }

    return { userId: payload.userId };
  } catch {
    return null;
  }
}

export function getBearerToken(request: Request): string | null {
  const header = request.headers.get("authorization")?.trim();
  if (!header?.toLowerCase().startsWith("bearer ")) {
    return null;
  }
  const token = header.slice(7).trim();
  return token.length > 0 ? token : null;
}

export function getSessionUserId(request: Request): string | null {
  const token = getBearerToken(request);
  if (!token) {
    return null;
  }
  return verifySessionToken(token)?.userId ?? null;
}
