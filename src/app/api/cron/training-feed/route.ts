import { NextResponse } from "next/server";

import { hasMongoConfig } from "@/lib/env";
import { processNextAnalysisJob } from "@/lib/training-feed";

export const runtime = "nodejs";
export const maxDuration = 60;

/** Vercel Cron — analysis_jobs 큐 배치 처리 (refresh_user_feed / refresh_user_profile) */
export async function GET(request: Request) {
  const secret = process.env.CRON_SECRET?.trim();
  if (!secret) {
    return NextResponse.json(
      { error: "CRON_SECRET not configured" },
      { status: 503 },
    );
  }

  const auth = request.headers.get("authorization")?.trim();
  if (auth !== `Bearer ${secret}`) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  if (!hasMongoConfig()) {
    return NextResponse.json({ error: "MongoDB not configured" }, { status: 503 });
  }

  let processed = 0;
  const maxJobs = Math.min(
    20,
    Math.max(1, Number(process.env.CRON_TRAINING_FEED_MAX_JOBS ?? 8) || 8),
  );

  while (processed < maxJobs && (await processNextAnalysisJob())) {
    processed += 1;
  }

  return NextResponse.json({ ok: true, processed });
}
