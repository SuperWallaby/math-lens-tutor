import { NextResponse } from "next/server";

import { getAuthenticatedUser, authErrorResponse } from "@/lib/request";
import { getLinkedStudents, publicUser } from "@/lib/users";

export async function GET(request: Request) {
  try {
    const user = await getAuthenticatedUser(request);
    const linkedStudents =
      user.role === "parent" || user.role === "teacher"
        ? await getLinkedStudents(user.id)
        : [];

    return NextResponse.json({
      user: publicUser(user),
      linkedStudents,
    });
  } catch (error) {
    const authResponse = authErrorResponse(error);
    if (authResponse) {
      return authResponse;
    }

    return NextResponse.json(
      { error: "사용자 정보를 불러오지 못했습니다." },
      { status: 500 },
    );
  }
}
