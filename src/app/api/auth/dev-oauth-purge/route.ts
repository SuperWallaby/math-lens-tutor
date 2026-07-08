import { NextResponse } from "next/server";
import { z } from "zod";

import {
  findDevOAuthLoginAccount,
  getDevOAuthLoginAccounts,
  resolveDevOAuthAccountUserId,
} from "@/lib/dev-oauth-accounts";
import { isDevEnvironment } from "@/lib/is-dev";
import { hasMongoConfig } from "@/lib/env";
import { deleteUserAccount, findUserById } from "@/lib/users";

const bodySchema = z.object({
  accountId: z.string().min(1),
});

export async function GET() {
  if (!isDevEnvironment()) {
    return NextResponse.json({ error: "Not found" }, { status: 404 });
  }

  return NextResponse.json({
    accounts: getDevOAuthLoginAccounts().map((account) => ({
      id: account.id,
      label: account.label,
      email: account.email,
      provider: account.provider,
    })),
  });
}

export async function POST(request: Request) {
  if (!isDevEnvironment()) {
    return NextResponse.json({ error: "Not found" }, { status: 404 });
  }

  if (!hasMongoConfig()) {
    return NextResponse.json(
      { error: "DB 설정이 완료되지 않았습니다." },
      { status: 503 },
    );
  }

  try {
    const body = bodySchema.parse(await request.json());
    const spec = findDevOAuthLoginAccount(body.accountId);
    if (!spec) {
      return NextResponse.json(
        { error: "알 수 없는 개발용 OAuth 계정입니다." },
        { status: 400 },
      );
    }

    const userId = await resolveDevOAuthAccountUserId(spec);
    if (!userId) {
      return NextResponse.json(
        {
          error: `${spec.label} 계정을 찾을 수 없습니다. 이미 삭제되었을 수 있습니다.`,
          alreadyDeleted: true,
        },
        { status: 404 },
      );
    }

    const user = await findUserById(userId);
    if (!user) {
      return NextResponse.json({
        ok: true,
        alreadyDeleted: true,
        accountId: spec.id,
        label: spec.label,
      });
    }

    await deleteUserAccount(userId);

    return NextResponse.json({
      ok: true,
      accountId: spec.id,
      label: spec.label,
      deletedUserId: userId,
      email: user.email ?? spec.email,
      provider: user.oauthProvider ?? spec.provider,
    });
  } catch (error) {
    const message =
      error instanceof Error
        ? error.message
        : "개발용 OAuth 계정 삭제에 실패했습니다.";
    return NextResponse.json({ error: message }, { status: 400 });
  }
}
