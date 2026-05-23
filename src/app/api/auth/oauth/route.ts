import { NextResponse } from "next/server";
import { z } from "zod";

import { signSessionToken } from "@/lib/auth";
import { hasAuthConfig, hasMongoConfig } from "@/lib/env";
import { verifyOAuthToken } from "@/lib/oauth-verify";
import { getDeviceUserId } from "@/lib/request";
import { publicUser, upsertOAuthUser } from "@/lib/users";

const oauthBodySchema = z.object({
  provider: z.enum(["kakao", "google", "apple"]),
  idToken: z.string().optional(),
  accessToken: z.string().optional(),
  displayName: z.string().optional(),
});

export async function POST(request: Request) {
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
    const body = oauthBodySchema.parse(await request.json());
    const identity = await verifyOAuthToken(body);
    const deviceUserId = getDeviceUserId(request);
    const user = await upsertOAuthUser(identity, deviceUserId);
    const token = signSessionToken({ userId: user.id });

    return NextResponse.json({
      token,
      user: publicUser(user),
    });
  } catch (error) {
    const message =
      error instanceof Error ? error.message : "간편 가입에 실패했습니다.";
    return NextResponse.json({ error: message }, { status: 400 });
  }
}
