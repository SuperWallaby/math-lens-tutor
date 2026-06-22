import { createHash, randomBytes } from "crypto";

import { getMongoDb } from "./mongodb";

export type MagicLinkIntent = "signup" | "login";

type MagicLinkTokenDoc = {
  id: string;
  email: string;
  tokenHash: string;
  intent: MagicLinkIntent;
  createdAt: string;
  expiresAt: string;
  usedAt?: string;
};

type MemoryMagicLinkDb = {
  tokens: MagicLinkTokenDoc[];
};

const globalForMagic = globalThis as typeof globalThis & {
  mathTutorMagicLinkDb?: MemoryMagicLinkDb;
};

const memoryDb =
  globalForMagic.mathTutorMagicLinkDb ??
  (globalForMagic.mathTutorMagicLinkDb = { tokens: [] });

const TOKEN_TTL_MS = 15 * 60 * 1000;

export function normalizeEmail(email: string): string {
  return email.trim().toLowerCase();
}

export function isValidEmail(email: string): boolean {
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(normalizeEmail(email));
}

/** `devstudy*@wooyeol.com` — 매직 링크 없이 즉시 로그인 (로컬·프로덕션) */
export function isDevMagicLinkBypassEmail(email: string): boolean {
  const prefix =
    process.env.DEV_MAGIC_LINK_BYPASS_PREFIX?.trim().toLowerCase() ||
    "devstudy";
  const domain =
    process.env.DEV_MAGIC_LINK_BYPASS_DOMAIN?.trim().toLowerCase() ||
    "wooyeol.com";

  const normalized = normalizeEmail(email);
  const at = normalized.lastIndexOf("@");
  if (at <= 0) return false;

  const local = normalized.slice(0, at);
  const emailDomain = normalized.slice(at + 1);
  if (emailDomain !== domain) return false;

  return local.startsWith(prefix);
}

/** Play / App Store 심사용 — Vercel `PLAY_REVIEW_EMAILS` 에 등록된 주소만 (production 허용) */
export function isPlayReviewBypassEmail(email: string): boolean {
  const raw = process.env.PLAY_REVIEW_EMAILS?.trim();
  if (!raw) return false;

  const normalized = normalizeEmail(email);
  const allowed = raw
    .split(",")
    .map((item) => normalizeEmail(item.trim()))
    .filter(Boolean);

  return allowed.includes(normalized);
}

export function isMagicLinkInstantLoginEmail(email: string): boolean {
  return (
    isDevMagicLinkBypassEmail(email) || isPlayReviewBypassEmail(email)
  );
}

function hashToken(rawToken: string): string {
  return createHash("sha256").update(rawToken).digest("hex");
}

function displayNameFromEmail(email: string): string {
  const local = email.split("@")[0]?.trim();
  return local && local.length > 0 ? local : "우열 사용자";
}

export function emailOAuthSubject(email: string): string {
  return normalizeEmail(email);
}

export { displayNameFromEmail };

async function ensureIndexes() {
  const db = await getMongoDb();
  if (!db) return;
  await db.collection<MagicLinkTokenDoc>("magic_link_tokens").createIndex(
    { tokenHash: 1 },
    { unique: true },
  );
  await db.collection<MagicLinkTokenDoc>("magic_link_tokens").createIndex(
    { expiresAt: 1 },
    { expireAfterSeconds: 0 },
  );
}

async function saveToken(doc: MagicLinkTokenDoc) {
  const db = await getMongoDb();
  if (!db) {
    memoryDb.tokens.unshift(doc);
    return;
  }
  await ensureIndexes();
  await db.collection<MagicLinkTokenDoc>("magic_link_tokens").insertOne(doc);
}

async function findToken(rawToken: string): Promise<MagicLinkTokenDoc | null> {
  const tokenHash = hashToken(rawToken);
  const db = await getMongoDb();
  if (!db) {
    return (
      memoryDb.tokens.find(
        (item) => item.tokenHash === tokenHash && !item.usedAt,
      ) ?? null
    );
  }
  await ensureIndexes();
  return db
    .collection<MagicLinkTokenDoc>("magic_link_tokens")
    .findOne({ tokenHash, usedAt: { $exists: false } }, { projection: { _id: 0 } });
}

async function markUsed(rawToken: string) {
  const tokenHash = hashToken(rawToken);
  const usedAt = new Date().toISOString();
  const db = await getMongoDb();
  if (!db) {
    const item = memoryDb.tokens.find((row) => row.tokenHash === tokenHash);
    if (item) item.usedAt = usedAt;
    return;
  }
  await db
    .collection<MagicLinkTokenDoc>("magic_link_tokens")
    .updateOne({ tokenHash }, { $set: { usedAt } });
}

export async function createMagicLinkToken(
  email: string,
  intent: MagicLinkIntent,
): Promise<{ rawToken: string; normalizedEmail: string }> {
  const normalizedEmail = normalizeEmail(email);
  const rawToken = randomBytes(32).toString("base64url");
  const now = Date.now();
  const doc: MagicLinkTokenDoc = {
    id: randomBytes(12).toString("hex"),
    email: normalizedEmail,
    tokenHash: hashToken(rawToken),
    intent,
    createdAt: new Date(now).toISOString(),
    expiresAt: new Date(now + TOKEN_TTL_MS).toISOString(),
  };
  await saveToken(doc);
  return { rawToken, normalizedEmail };
}

export async function consumeMagicLinkToken(rawToken: string): Promise<{
  email: string;
  intent: MagicLinkIntent;
} | null> {
  const trimmed = rawToken.trim();
  if (!trimmed) return null;

  const doc = await findToken(trimmed);
  if (!doc) return null;
  if (Date.parse(doc.expiresAt) < Date.now()) return null;

  await markUsed(trimmed);
  return { email: doc.email, intent: doc.intent };
}
