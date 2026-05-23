import { NextResponse } from "next/server";

import { authErrorResponse, requireAuthenticatedUser } from "@/lib/request";
import { getLinkedStudents } from "@/lib/users";

export async function GET(request: Request) {
  try {
    const user = await requireAuthenticatedUser(request);
    if (user.role === "student") {
      return NextResponse.json({ students: [] });
    }

    const students = await getLinkedStudents(user.id);
    return NextResponse.json({ students });
  } catch (error) {
    const authResponse = authErrorResponse(error);
    if (authResponse) {
      return authResponse;
    }

    return NextResponse.json(
      { error: "연결된 학생 목록을 불러오지 못했습니다." },
      { status: 500 },
    );
  }
}
