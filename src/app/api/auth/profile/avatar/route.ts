import { NextResponse } from "next/server";

import { getSessionUserId } from "@/lib/auth";
import { authErrorResponse } from "@/lib/request";
import { publicUser, setUserProfileImage } from "@/lib/users";

export async function POST(request: Request) {
  const authUserId = getSessionUserId(request);
  if (!authUserId) {
    return NextResponse.json(
      { error: "로그인이 필요합니다." },
      { status: 401 },
    );
  }

  try {
    const formData = await request.formData();
    const image = formData.get("image");
    if (!(image instanceof File) || image.size === 0) {
      return NextResponse.json(
        { error: "프로필 이미지 파일이 필요합니다." },
        { status: 400 },
      );
    }

    if (!image.type.startsWith("image/")) {
      return NextResponse.json(
        { error: "이미지 파일만 업로드할 수 있습니다." },
        { status: 400 },
      );
    }

    const user = await setUserProfileImage(authUserId, image);

    return NextResponse.json({
      user: publicUser(user),
    });
  } catch (error) {
    const authResponse = authErrorResponse(error);
    if (authResponse) {
      return authResponse;
    }

    const message =
      error instanceof Error
        ? error.message
        : "프로필 이미지 업로드에 실패했습니다.";
    return NextResponse.json({ error: message }, { status: 400 });
  }
}
