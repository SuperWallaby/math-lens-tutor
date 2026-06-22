import { NextResponse } from "next/server";
import { z } from "zod";

import { signSessionToken } from "@/lib/auth";
import { hasAuthConfig, hasMongoConfig } from "@/lib/env";
import { consumeMagicLinkToken } from "@/lib/magic-link";
import { getDeviceUserId } from "@/lib/request";
import {
  OAuthAccountExistsError,
  publicUser,
  upsertMagicLinkUser,
} from "@/lib/users";

const bodySchema = z.object({
  token: z.string().min(10),
});

export async function POST(request: Request) {
  if (!hasMongoConfig() || !hasAuthConfig()) {
    return NextResponse.json(
      { error: "인증 설정이 완료되지 않았습니다." },
      { status: 503 },
    );
  }

  try {
    const body = bodySchema.parse(await request.json());
    const consumed = await consumeMagicLinkToken(body.token);
    if (!consumed) {
      return NextResponse.json(
        { error: "링크가 만료되었거나 이미 사용되었습니다." },
        { status: 400 },
      );
    }

    const deviceUserId = getDeviceUserId(request);
    const user = await upsertMagicLinkUser(consumed.email, deviceUserId, {
      intent: consumed.intent,
    });
    const token = signSessionToken({ userId: user.id });

    return NextResponse.json({
      token,
      user: publicUser(user),
    });
  } catch (error) {
    if (error instanceof OAuthAccountExistsError) {
      return NextResponse.json({ error: error.message }, { status: 409 });
    }
    const message =
      error instanceof Error ? error.message : "로그인에 실패했습니다.";
    return NextResponse.json({ error: message }, { status: 400 });
  }
}
