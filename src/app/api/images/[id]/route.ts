import { NextResponse } from "next/server";
import { withRequestDb } from "@/lib/db-variant";
import { getFromR2 } from "@/lib/object-storage";
import { getMongoDb } from "@/lib/mongodb";

type StoredImage = {
  id: string;
  mimeType: string;
  data?: string;
  storage?: "mongo" | "r2";
  r2Key?: string;
};

export const runtime = "nodejs";

export async function GET(
  request: Request,
  { params }: { params: Promise<{ id: string }> },
) {
  return withRequestDb(request, async () => {
  const { id } = await params;
  const db = await getMongoDb();

  if (!db) {
    return NextResponse.json(
      { error: "MongoDB가 연결되지 않았습니다." },
      { status: 404 },
    );
  }

  const image = await db
    .collection<StoredImage>("solution_images")
    .findOne({ id }, { projection: { _id: 0 } });

  if (!image) {
    return NextResponse.json(
      { error: "이미지를 찾을 수 없습니다." },
      { status: 404 },
    );
  }

  if (image.storage === "r2" && image.r2Key) {
    const object = await getFromR2(image.r2Key);
    if (!object) {
      return NextResponse.json(
        { error: "이미지를 찾을 수 없습니다." },
        { status: 404 },
      );
    }

    return new Response(new Uint8Array(object.body), {
      headers: {
        "Content-Type": object.contentType || image.mimeType,
        "Cache-Control": "private, max-age=3600",
      },
    });
  }

  if (!image.data) {
    return NextResponse.json(
      { error: "이미지 데이터가 없습니다." },
      { status: 404 },
    );
  }

  return new Response(Buffer.from(image.data, "base64"), {
    headers: {
      "Content-Type": image.mimeType,
      "Cache-Control": "private, max-age=3600",
    },
  });
  });
}
