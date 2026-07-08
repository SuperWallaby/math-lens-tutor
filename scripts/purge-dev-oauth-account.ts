/**
 * 개발용 OAuth 테스트 계정 탈퇴·데이터 삭제.
 *
 * 사용:
 *   node --env-file=.env.local --import tsx scripts/purge-dev-oauth-account.ts kakao-crawl123
 *   node --env-file=.env.local --import tsx scripts/purge-dev-oauth-account.ts --all
 */
import {
  findDevOAuthLoginAccount,
  getDevOAuthLoginAccounts,
  resolveDevOAuthAccountUserId,
} from "../src/lib/dev-oauth-accounts";
import { deleteUserAccount, findUserById } from "../src/lib/users";

async function purgeAccount(accountId: string): Promise<void> {
  const spec = findDevOAuthLoginAccount(accountId);
  if (!spec) {
    throw new Error(`알 수 없는 accountId: ${accountId}`);
  }

  const userId = await resolveDevOAuthAccountUserId(spec);
  if (!userId) {
    console.log(`[skip] ${spec.label} — 계정 없음 (이미 삭제됨)`);
    return;
  }

  const user = await findUserById(userId);
  if (!user) {
    console.log(`[skip] ${spec.label} — userId ${userId} 없음`);
    return;
  }

  await deleteUserAccount(userId);
  console.log(
    `[deleted] ${spec.label} — ${userId} (${user.displayName ?? "no-name"})`,
  );
}

async function main() {
  const arg = process.argv[2]?.trim();
  if (!arg) {
    console.error(
      "Usage: purge-dev-oauth-account.ts <accountId|--all>\n" +
        "  accountIds: " +
        getDevOAuthLoginAccounts()
          .map((item) => item.id)
          .join(", "),
    );
    process.exit(1);
  }

  if (arg === "--all") {
    for (const account of getDevOAuthLoginAccounts()) {
      await purgeAccount(account.id);
    }
    console.log("\n완료.");
    return;
  }

  await purgeAccount(arg);
  console.log("\n완료.");
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
