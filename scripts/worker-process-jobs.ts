#!/usr/bin/env node
/**
 * Atlas analysis_jobs 큐를 처리해 user_feed_queue 를 갱신합니다.
 *
 *   npm run worker:training-feed
 *   npm run worker:training-feed -- --once
 *   npm run worker:training-feed -- --interval=30
 *
 * GPU LLM (Ollama 호환):
 *   GPU_LLM_BASE_URL=http://127.0.0.1:11434
 *   GPU_LLM_MODEL=qwen2.5:7b
 */
import { hasMongoConfig } from "../src/lib/env";
import { getMongoDb } from "../src/lib/mongodb";
import { processNextAnalysisJob } from "../src/lib/training-feed";

type CliOptions = {
  once: boolean;
  intervalSec: number;
};

function parseArgs(argv: string[]): CliOptions {
  const opts: CliOptions = { once: false, intervalSec: 60 };
  for (const arg of argv) {
    if (arg === "--once") opts.once = true;
    if (arg.startsWith("--interval=")) {
      opts.intervalSec = Math.max(5, Number(arg.split("=")[1]) || 60);
    }
  }
  return opts;
}

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function main() {
  const opts = parseArgs(process.argv.slice(2));

  if (!hasMongoConfig()) {
    console.error("MONGODB_URI 가 설정되지 않았습니다.");
    process.exit(1);
  }

  const db = await getMongoDb();
  if (!db) {
    console.error("MongoDB 에 연결하지 못했습니다.");
    process.exit(1);
  }

  console.log(
    `[training-feed-worker] started interval=${opts.intervalSec}s once=${opts.once}`,
  );

  do {
    let processed = 0;
    while (await processNextAnalysisJob()) {
      processed += 1;
    }
    if (processed > 0) {
      console.log(`[training-feed-worker] processed ${processed} job(s)`);
    } else if (opts.once) {
      console.log("[training-feed-worker] no pending jobs");
    }

    if (opts.once) break;
    await sleep(opts.intervalSec * 1000);
  } while (true);
}

main().catch((error) => {
  console.error("[training-feed-worker] fatal", error);
  process.exit(1);
});
