import { NextResponse } from "next/server";

import { getSessionUserId } from "@/lib/auth";
import { authErrorResponse } from "@/lib/request";
import { publicUser, resetUserProfileRole } from "@/lib/users";

export async function POST(request: Request) {
  const authUserId = getSessionUserId(request);
  if (!authUserId) {
    return NextResponse.json(
      { error: "로그인이 필요합니다." },
      { status: 401 },
    );
  }

  try {
    const user = await resetUserProfileRole(authUserId);
    return NextResponse.json({
      user: publicUser(user),
    });
  } catch (error) {
    const authResponse = authErrorResponse(error);
    if (authResponse) {
      return authResponse;
    }

    const message =
      error instanceof Error ? error.message : "역할 초기화에 실패했습니다.";
    return NextResponse.json({ error: message }, { status: 400 });
  }
}
