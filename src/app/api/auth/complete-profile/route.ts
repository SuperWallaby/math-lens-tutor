import { NextResponse } from "next/server";
import { z } from "zod";

import {
  invalidateLearningProfileSnapshot,
  refreshLearningProfileAfterWrite,
} from "@/lib/learning-profile-snapshot";
import { getSessionUserId } from "@/lib/auth";
import { authErrorResponse } from "@/lib/request";
import { completeUserProfile, findUserById, publicUser } from "@/lib/users";

const bodySchema = z.object({
  role: z.enum(["student", "parent", "teacher"]),
  age: z.number().int().min(8).max(99).optional(),
  grade: z.string().optional(),
  organizationName: z.string().optional(),
});

export async function POST(request: Request) {
  const authUserId = getSessionUserId(request);
  if (!authUserId) {
    return NextResponse.json(
      { error: "로그인이 필요합니다." },
      { status: 401 },
    );
  }

  try {
    const existing = await findUserById(authUserId);
    if (!existing) {
      return NextResponse.json(
        { error: "사용자를 찾을 수 없습니다." },
        { status: 404 },
      );
    }

    const body = bodySchema.parse(await request.json());

    if (existing.profileComplete && existing.role === body.role) {
      return NextResponse.json({
        user: publicUser(existing),
      });
    }

    if (body.role === "teacher") {
      return NextResponse.json(
        { error: "교사 계정은 현재 준비 중입니다. 학생 또는 학부모로 시작해 주세요." },
        { status: 403 },
      );
    }

    const user = await completeUserProfile(authUserId, body.role, {
      age: body.age,
      grade: body.grade,
      organizationName: body.organizationName,
    });

    await invalidateLearningProfileSnapshot(authUserId);
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
      error instanceof Error ? error.message : "프로필 설정에 실패했습니다.";
    return NextResponse.json({ error: message }, { status: 400 });
  }
}
