/**
 * 개발/검수용 계정만 남기고 users·연결·학습 데이터 삭제.
 *
 * 유지:
 * - devstudy*@wooyeol.com (매직 링크 bypass)
 * - PLAY_REVIEW_EMAILS 에 등록된 이메일
 * - oauthSubject dev:empty-* (로컬 dev 계정)
 *
 * 사용: node --env-file=.env.local --import tsx scripts/purge-non-review-users.ts
 *       node --env-file=.env.local --import tsx scripts/purge-non-review-users.ts --dry-run
 */
import { deleteUserAccount, findUserById } from "../src/lib/users";
import { getMongoDb } from "../src/lib/mongodb";
import {
  isDevMagicLinkBypassEmail,
  isPlayReviewBypassEmail,
} from "../src/lib/magic-link";
import type { User } from "../src/lib/types";

function isReviewDevstudyEmail(email: string): boolean {
  const normalized = email.trim().toLowerCase();
  const at = normalized.lastIndexOf("@");
  if (at <= 0) return false;
  const local = normalized.slice(0, at);
  const domain = normalized.slice(at + 1);
  return domain === "wooyeol.com" && local.startsWith("devstudy");
}

function shouldKeepUser(user: User): boolean {
  const email = user.email?.trim().toLowerCase() ?? "";
  if (email && (isReviewDevstudyEmail(email) || isDevMagicLinkBypassEmail(email))) {
    return true;
  }
  if (email && isPlayReviewBypassEmail(email)) {
    return true;
  }
  if (user.oauthProvider === "email" && user.oauthSubject) {
    if (
      isReviewDevstudyEmail(user.oauthSubject) ||
      isDevMagicLinkBypassEmail(user.oauthSubject)
    ) {
      return true;
    }
    if (isPlayReviewBypassEmail(user.oauthSubject)) {
      return true;
    }
  }
  if (user.oauthSubject?.startsWith("dev:empty-")) {
    return true;
  }
  return false;
}

async function listAllUsers(): Promise<User[]> {
  const db = await getMongoDb();
  if (!db) {
    console.error("MongoDB 연결 없음. MONGODB_URI 확인.");
    process.exit(1);
  }
  return db
    .collection<User>("users")
    .find({}, { projection: { _id: 0 } })
    .toArray();
}

async function main() {
  const dryRun = process.argv.includes("--dry-run");
  const users = await listAllUsers();

  const toDelete = users.filter((user) => !shouldKeepUser(user));
  const kept = users.filter((user) => shouldKeepUser(user));

  console.log(`총 ${users.length}명 · 유지 ${kept.length} · 삭제 ${toDelete.length}`);
  if (kept.length > 0) {
    console.log("\n[유지]");
    for (const user of kept) {
      console.log(
        `  - ${user.email ?? user.oauthSubject ?? user.id} (${user.role ?? "no-role"})`,
      );
    }
  }

  if (toDelete.length === 0) {
    console.log("\n삭제할 계정 없음.");
    return;
  }

  console.log("\n[삭제 예정]");
  for (const user of toDelete) {
    console.log(
      `  - ${user.email ?? user.oauthSubject ?? user.id} (${user.role ?? "no-role"})`,
    );
  }

  if (dryRun) {
    console.log("\n--dry-run: 실제 삭제하지 않았습니다.");
    return;
  }

  for (const user of toDelete) {
    const fresh = await findUserById(user.id);
    if (!fresh) continue;
    await deleteUserAccount(user.id);
    console.log(`삭제됨: ${user.email ?? user.oauthSubject ?? user.id}`);
  }

  console.log("\n완료.");
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
