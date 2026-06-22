import { NextResponse } from "next/server";
import { z } from "zod";

import { signSessionToken } from "@/lib/auth";
import { findDevAccount } from "@/lib/dev-accounts";
import { hasAuthConfig, hasMongoConfig } from "@/lib/env";
import { isDevEnvironment } from "@/lib/is-dev";
import { getDeviceUserId } from "@/lib/request";
import { publicUser, resetDevLoginAccount } from "@/lib/users";

const bodySchema = z.object({
  accountId: z.string().min(1),
});

export async function POST(request: Request) {
  if (!isDevEnvironment()) {
    return NextResponse.json({ error: "Not found" }, { status: 404 });
  }

  if (!hasMongoConfig()) {
    return NextResponse.json(
      { error: "계정 저장소가 설정되지 않았습니다. MongoDB 연결이 필요합니다." },
      { status: 503 },
    );
  }

  if (!hasAuthConfig()) {
    return NextResponse.json(
      { error: "인증 설정이 완료되지 않았습니다." },
      { status: 503 },
    );
  }

  try {
    const body = bodySchema.parse(await request.json());
    const spec = findDevAccount(body.accountId);
    if (!spec) {
      return NextResponse.json(
        { error: "알 수 없는 개발용 계정입니다." },
        { status: 400 },
      );
    }

    const deviceUserId = getDeviceUserId(request);
    const user = await resetDevLoginAccount(spec, deviceUserId);
    const token = signSessionToken({ userId: user.id });

    return NextResponse.json({
      token,
      user: publicUser(user),
    });
  } catch (error) {
    const message =
      error instanceof Error ? error.message : "개발용 로그인에 실패했습니다.";
    return NextResponse.json({ error: message }, { status: 400 });
  }
}
