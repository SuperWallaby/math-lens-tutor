import { NextResponse } from "next/server";

import { getSessionUserId } from "@/lib/auth";
import { authErrorResponse } from "@/lib/request";
import { deleteUserAccount } from "@/lib/users";

export async function DELETE(request: Request) {
  const authUserId = getSessionUserId(request);
  if (!authUserId) {
    return NextResponse.json(
      { error: "로그인이 필요합니다." },
      { status: 401 },
    );
  }

  try {
    await deleteUserAccount(authUserId);

    return NextResponse.json({ ok: true });
  } catch (error) {
    const authResponse = authErrorResponse(error);
    if (authResponse) {
      return authResponse;
    }

    const message =
      error instanceof Error ? error.message : "계정 탈퇴에 실패했습니다.";
    return NextResponse.json({ error: message }, { status: 400 });
  }
}
