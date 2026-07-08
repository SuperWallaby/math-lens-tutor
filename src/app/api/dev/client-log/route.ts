import { appendFileSync } from "node:fs";
import { join } from "node:path";

import { NextResponse } from "next/server";

const LOG_PATH =
  process.env.DEBUG_LOG_PATH ??
  join(process.cwd(), ".cursor", "debug-6366de.log");

export async function POST(request: Request) {
  if (process.env.NODE_ENV === "production") {
    return NextResponse.json({ ok: false }, { status: 404 });
  }

  try {
    const body = (await request.json()) as Record<string, unknown>;
    const line =
      JSON.stringify({
        sessionId: "6366de",
        timestamp: Date.now(),
        ...body,
      }) + "\n";
    appendFileSync(LOG_PATH, line, "utf8");
    return NextResponse.json({ ok: true });
  } catch {
    return NextResponse.json({ ok: false }, { status: 400 });
  }
}
