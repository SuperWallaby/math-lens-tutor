import { NextResponse } from "next/server";
import { z } from "zod";

import {
  invalidateLearningProfileSnapshot,
  refreshLearningProfileAfterWrite,
} from "@/lib/learning-profile-snapshot";
import { getSessionUserId } from "@/lib/auth";
import { authErrorResponse } from "@/lib/request";
import { publicUser, updateUserProfile } from "@/lib/users";

const bodySchema = z.object({
  displayName: z.string().min(1).max(40).optional(),
  grade: z.string().optional(),
  organizationName: z.string().max(80).optional(),
});

export async function PATCH(request: Request) {
  const authUserId = getSessionUserId(request);
  if (!authUserId) {
    return NextResponse.json(
      { error: "로그인이 필요합니다." },
      { status: 401 },
    );
  }

  try {
    const body = bodySchema.parse(await request.json());
    const user = await updateUserProfile(authUserId, body);

    if (body.grade !== undefined) {
      await invalidateLearningProfileSnapshot(authUserId);
    }
    await refreshLearningProfileAfterWrite(authUserId, user.grade);

    return NextResponse.json({
      user: publicUser(user),
    });
  } catch (error) {
    const authResponse = authErrorResponse(error);
    if (authResponse) {
      return authResponse;
    }

    const message =
      error instanceof Error ? error.message : "프로필 수정에 실패했습니다.";
    return NextResponse.json({ error: message }, { status: 400 });
  }
}
