import { NextResponse } from "next/server";
import { z } from "zod";

import { signSessionToken } from "@/lib/auth";
import {
  findDevOAuthLoginAccount,
  getDevOAuthLoginAccounts,
  resolveDevOAuthAccountUserId,
} from "@/lib/dev-oauth-accounts";
import { isDevEnvironment } from "@/lib/is-dev";
import { hasAuthConfig, hasMongoConfig } from "@/lib/env";
import { getDeviceUserId } from "@/lib/request";
import {
  getLinkedStudents,
  loginDevOAuthUser,
  publicUser,
} from "@/lib/users";

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

  if (!hasMongoConfig() || !hasAuthConfig()) {
    return NextResponse.json(
      { error: "인증·DB 설정이 완료되지 않았습니다." },
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
          error: `${spec.label} 계정을 찾을 수 없습니다. DEV_OAUTH_*_USER_ID 를 확인해 주세요.`,
        },
        { status: 404 },
      );
    }

    const deviceUserId = getDeviceUserId(request);
    const user = await loginDevOAuthUser({
      userId,
      provider: spec.provider,
      deviceUserId,
    });

    const token = signSessionToken({ userId: user.id });
    const linkedStudents =
      user.role === "parent" || user.role === "teacher"
        ? await getLinkedStudents(user.id)
        : [];

    return NextResponse.json({
      token,
      user: publicUser(user),
      linkedStudents,
    });
  } catch (error) {
    const message =
      error instanceof Error ? error.message : "개발용 OAuth 로그인에 실패했습니다.";
    return NextResponse.json({ error: message }, { status: 400 });
  }
}
