import { NextResponse } from "next/server";
import { z } from "zod";

import { authErrorResponse, requireAuthenticatedUser } from "@/lib/request";
import { updateLinkedStudentGuardianLabel } from "@/lib/users";

const bodySchema = z.object({
  guardianLabel: z.string().max(40).nullable().optional(),
});

export async function PATCH(
  request: Request,
  { params }: { params: Promise<{ studentId: string }> },
) {
  try {
    const user = await requireAuthenticatedUser(request);
    if (user.role === "student") {
      return NextResponse.json({ error: "권한이 없습니다." }, { status: 403 });
    }

    const { studentId } = await params;
    const body = bodySchema.parse(await request.json());
    const raw = body.guardianLabel;
    const guardianLabel =
      raw == null || raw.trim().length === 0 ? null : raw.trim();

    const student = await updateLinkedStudentGuardianLabel(
      user.id,
      studentId,
      guardianLabel,
    );

    return NextResponse.json({ student });
  } catch (error) {
    const authResponse = authErrorResponse(error);
    if (authResponse) {
      return authResponse;
    }

    const message =
      error instanceof Error ? error.message : "표시 이름을 저장하지 못했습니다.";
    return NextResponse.json({ error: message }, { status: 400 });
  }
}
