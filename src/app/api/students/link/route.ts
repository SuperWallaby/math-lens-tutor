import { NextResponse } from "next/server";
import { z } from "zod";

import { authErrorResponse, requireAuthenticatedUser } from "@/lib/request";
import { linkStudentToGuardian } from "@/lib/users";

const bodySchema = z.object({
  studentCode: z.string().min(4),
});

export async function POST(request: Request) {
  try {
    const user = await requireAuthenticatedUser(request);
    const body = bodySchema.parse(await request.json());
    const student = await linkStudentToGuardian(user.id, body.studentCode);

    return NextResponse.json({ student });
  } catch (error) {
    const authResponse = authErrorResponse(error);
    if (authResponse) {
      return authResponse;
    }

    const message =
      error instanceof Error ? error.message : "학생 연결에 실패했습니다.";
    return NextResponse.json({ error: message }, { status: 400 });
  }
}
