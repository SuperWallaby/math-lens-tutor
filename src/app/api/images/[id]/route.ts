import { NextResponse } from "next/server";
import { getMongoDb } from "@/lib/mongodb";

type StoredImage = {
  id: string;
  mimeType: string;
  data: string;
};

export const runtime = "nodejs";

export async function GET(
  _request: Request,
  { params }: { params: Promise<{ id: string }> },
) {
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

  return new Response(Buffer.from(image.data, "base64"), {
    headers: {
      "Content-Type": image.mimeType,
      "Cache-Control": "private, max-age=3600",
    },
  });
}
