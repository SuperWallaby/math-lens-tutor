import { NextResponse } from "next/server";
import { z } from "zod";

import { signSessionToken } from "@/lib/auth";
import { sendMagicLinkEmail } from "@/lib/email";
import { hasAuthConfig, hasMongoConfig } from "@/lib/env";
import {
  createMagicLinkToken,
  isMagicLinkInstantLoginEmail,
  isPlayReviewBypassEmail,
  isValidEmail,
  normalizeEmail,
} from "@/lib/magic-link";
import { getDeviceUserId } from "@/lib/request";
import {
  OAuthAccountExistsError,
  publicUser,
  upsertMagicLinkUser,
} from "@/lib/users";

const bodySchema = z.object({
  email: z.string().min(3).max(320),
  intent: z.enum(["signup", "login"]).optional().default("login"),
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
    const email = normalizeEmail(body.email);
    if (!isValidEmail(email)) {
      return NextResponse.json(
        { error: "올바른 이메일 주소를 입력해 주세요." },
        { status: 400 },
      );
    }

    if (isMagicLinkInstantLoginEmail(email)) {
      const deviceUserId = getDeviceUserId(request);
      const user = await upsertMagicLinkUser(email, deviceUserId, {
        intent: body.intent,
      });
      const token = signSessionToken({ userId: user.id });

      return NextResponse.json({
        ok: true,
        bypass: true,
        message: isPlayReviewBypassEmail(email)
          ? "Review account signed in."
          : "Bypass account signed in.",
        token,
        user: publicUser(user),
      });
    }

    const { rawToken } = await createMagicLinkToken(email, body.intent);
    const origin = request.headers.get("origin") ?? undefined;
    const delivery = await sendMagicLinkEmail({
      email,
      rawToken,
      requestOrigin: origin,
    });

    return NextResponse.json({
      ok: true,
      message: `${email} 로 로그인 링크를 보냈습니다. 메일함을 확인해 주세요.`,
      ...(process.env.NODE_ENV !== "production" && delivery.devLink
        ? { devLink: delivery.devLink }
        : {}),
    });
  } catch (error) {
    if (error instanceof OAuthAccountExistsError) {
      return NextResponse.json({ error: error.message }, { status: 409 });
    }
    const message =
      error instanceof Error ? error.message : "매직 링크 발송에 실패했습니다.";
    return NextResponse.json({ error: message }, { status: 400 });
  }
}
