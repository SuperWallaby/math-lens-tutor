#!/usr/bin/env node
/**
 * Training feed pipeline smoke test.
 *
 *   npm run smoke:training-feed
 *
 * 1) Atlas 연결
 * 2) 학습 데이터 있는 userId 선택
 * 3) analysis_jobs enqueue
 * 4) job 1회 처리 (로컬 또는 V100 SSH)
 * 5) user_feed_queues / job status 검증
 */
import { randomUUID } from "crypto";
import { execSync } from "child_process";

import { getMongoDb } from "../src/lib/mongodb";
import type { AnalysisJob, ProblemBankItem } from "../src/lib/types";
import {
  hashProblemContent,
  insertBankItem,
} from "../src/lib/problem-bank-store";
import {
  enqueueAnalysisJob,
  getUserFeedQueue,
} from "../src/lib/training-feed-store";
import { buildFallbackFeedItems, processNextAnalysisJob } from "../src/lib/training-feed";

const V100_SSH = process.env.V100_SSH_HOST ?? "lab-worker";
const RUN_ON_V100 = process.env.SMOKE_RUN_WORKER_ON_V100 !== "0";

function ok(label: string, detail?: string) {
  console.log(`OK  ${label}${detail ? ` — ${detail}` : ""}`);
}

function fail(label: string, detail?: string): never {
  console.error(`FAIL ${label}${detail ? ` — ${detail}` : ""}`);
  process.exit(1);
}

async function ensureSmokeBankItem(concept = "합성수"): Promise<string> {
  const db = await getMongoDb();
  if (!db) fail("mongodb");

  const existing = await db.collection<ProblemBankItem>("problem_bank_items").findOne(
    { originSubmissionId: "smoke:training-feed", active: true },
    { projection: { id: 1, _id: 0 } },
  );
  if (existing?.id) return existing.id;

  const prompt = `[smoke] ${concept} 연습 — 12와 18의 최소공배수는?`;
  const item: ProblemBankItem = {
    id: randomUUID(),
    contentHash: hashProblemContent({
      prompt,
      correctAnswer: "36",
      conceptTags: [concept],
    }),
    type: "free_response",
    title: `${concept} 스모크 테스트`,
    prompt,
    correctAnswer: "36",
    explanation: "12=2²×3, 18=2×3² → LCM=2²×3²=36",
    difficulty: "medium",
    conceptTags: [concept],
    conceptPrimary: concept,
    gradeBand: "m1",
    source: "imported",
    originSubmissionId: "smoke:training-feed",
    active: true,
    deliveryCount: 0,
    chart: null,
    jsxGraph: null,
    createdAt: new Date().toISOString(),
  };

  const saved = await insertBankItem(item);
  ok("seed smoke bank item", saved.id);
  return saved.id;
}

async function pickUserId(): Promise<string> {
  const db = await getMongoDb();
  if (!db) fail("mongodb", "getMongoDb returned null");

  const override = process.env.SMOKE_FEED_USER_ID?.trim();
  if (override) return override;

  const fromMistake = await db
    .collection("practice_mistake_records")
    .findOne({}, { projection: { userId: 1, _id: 0 }, sort: { createdAt: -1 } });
  if (fromMistake?.userId) return String(fromMistake.userId);

  fail("pick-user", "practice_mistake_records 에 데이터 없음");
}

async function waitForJobDoneById(jobId: string, timeoutMs = 300_000): Promise<AnalysisJob> {
  const db = await getMongoDb();
  if (!db) fail("mongodb");

  const started = Date.now();
  while (Date.now() - started < timeoutMs) {
    const job = await db.collection<AnalysisJob>("analysis_jobs").findOne(
      { id: jobId },
      { projection: { _id: 0 } },
    );
    if (!job) fail("job", `missing job ${jobId}`);
    if (job.status === "done") return job;
    if (job.status === "failed") {
      fail("job", job.error ?? "worker marked failed");
    }
    await new Promise((r) => setTimeout(r, 3000));
  }
  fail("job", "timeout waiting for done");
}

async function runWorkerOnce(): Promise<void> {
  if (RUN_ON_V100) {
    console.log(`… trigger V100 worker (--once) via ssh ${V100_SSH} (async poll)`);
    const { spawn } = await import("child_process");
    spawn(
      "ssh",
      [
        V100_SSH,
        "cd ~/v100/study-worker && export NVM_DIR=$HOME/.nvm && source $NVM_DIR/nvm.sh && node --env-file=.env --import tsx scripts/worker-process-jobs.ts -- --once",
      ],
      { stdio: "ignore", detached: true },
    ).unref();
    return;
  }

  let processed = 0;
  while (await processNextAnalysisJob()) {
    processed += 1;
  }
  console.log(`… local worker processed ${processed} job(s)`);
}

async function main() {
  const db = await getMongoDb();
  if (!db) fail("mongodb", "MONGODB_URI 확인");

  await db.command({ ping: 1 });
  ok("mongodb ping");

  const userId = await pickUserId();
  ok("pick userId", userId);

  await ensureSmokeBankItem("합성수");

  const preview = await buildFallbackFeedItems({ userId, limit: 3 });
  ok("fallback preview", `${preview.length} item(s) before worker`);
  if (preview.length === 0) {
    fail("fallback", "은행 시드 후에도 fallback 0 — gradeBand/개념 매칭 확인");
  }

  await enqueueAnalysisJob({ userId, type: "refresh_user_feed" });
  ok("enqueue refresh_user_feed job");

  const pending = await db.collection<AnalysisJob>("analysis_jobs").findOne(
    { userId, type: "refresh_user_feed", status: { $in: ["pending", "processing"] } },
    { projection: { _id: 0 }, sort: { createdAt: -1 } },
  );
  if (!pending) fail("enqueue", "pending job not found");
  ok("pending job in Atlas", pending.id);
  const jobId = pending.id;

  await runWorkerOnce();

  const job = await waitForJobDoneById(jobId);
  ok("job done", job.id);

  const queue = await getUserFeedQueue(userId);
  if (!queue || queue.items.length === 0) {
    fail("feed queue", "user_feed_queues empty — focus 개념/은행 풀 확인");
  }
  ok("feed queue", `${queue.items.length} items, source=${queue.source}`);

  const sample = queue.items[0];
  ok(
    "sample feed item",
    `${sample.concept} · ${sample.difficulty} · ${sample.reason.slice(0, 40)}`,
  );

  // Ollama reachable from V100 (informational)
  if (RUN_ON_V100) {
    try {
      const out = execSync(
        `ssh ${V100_SSH} 'curl -sS --max-time 5 http://127.0.0.1:11434/api/tags | python3 -c "import sys,json; print(len(json.load(sys.stdin).get(\\\"models\\\",[])))"'`,
        { encoding: "utf8", timeout: 15_000 },
      ).trim();
      ok("ollama on V100", `${out} model(s)`);
    } catch {
      console.log("WARN ollama check skipped");
    }
  }

  console.log("\nSmoke test passed.");
}

main().catch((error) => {
  console.error("FAIL unexpected", error);
  process.exit(1);
});
