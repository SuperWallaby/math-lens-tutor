#!/usr/bin/env node
/**
 * 기존 제출·피드에 listTitle / title 백필
 *
 *   npm run migrate:list-titles
 *   npm run migrate:list-titles -- --dry-run
 *   npm run migrate:list-titles -- --target feed
 *   npm run migrate:list-titles -- --batch-size 50
 */
import type { AnyBulkWriteOperation, Collection, Document } from "mongodb";

import { deriveSubmissionListTitle, normalizeListTitle } from "../src/lib/list-title";
import { getMongoDb } from "../src/lib/mongodb";
import type { SolutionSubmission, UserFeedQueue } from "../src/lib/types";

type Target = "submissions" | "feed" | "all";

type CliOptions = {
  dryRun: boolean;
  batchSize: number;
  target: Target;
};

function parseArgs(argv: string[]): CliOptions {
  const batchFlag = argv.findIndex((a) => a === "--batch-size");
  const targetFlag = argv.findIndex((a) => a === "--target");

  let target: Target = "all";
  if (targetFlag >= 0) {
    const value = argv[targetFlag + 1];
    if (value === "submissions" || value === "feed" || value === "all") {
      target = value;
    }
  }

  return {
    dryRun: argv.includes("--dry-run"),
    batchSize: batchFlag >= 0 ? Number(argv[batchFlag + 1]) || 100 : 100,
    target,
  };
}

async function flushBulk(
  col: Collection<Document>,
  ops: AnyBulkWriteOperation<Document>[],
  dryRun: boolean,
) {
  if (ops.length === 0) return;
  if (!dryRun) await col.bulkWrite(ops, { ordered: false });
  ops.length = 0;
}

async function migrateSubmissions(options: CliOptions) {
  const db = await getMongoDb();
  if (!db) throw new Error("MongoDB not configured");

  const col = db.collection<Document>("solution_submissions");
  const cursor = col.find({
    $or: [
      { "analysis.listTitle": { $exists: false } },
      { "analysis.listTitle": "" },
      { "analysis.listTitle": null },
      { "analysis.listTitle": /^사진/ },
      { "analysis.listTitle": { $regex: ".{40,}" } },
    ],
  });

  let scanned = 0;
  let updated = 0;
  const ops: AnyBulkWriteOperation<Document>[] = [];

  for await (const doc of cursor) {
    if (scanned >= options.batchSize) break;
    scanned += 1;
    const submission = doc as unknown as SolutionSubmission;
    if (!submission.analysis) continue;

    const listTitle = deriveSubmissionListTitle({
      listTitle: submission.analysis.listTitle,
      weakConcepts: submission.analysis.weakConcepts,
      recommendedFocus: submission.analysis.recommendedFocus,
      errorSummary: submission.analysis.errorSummary,
      problemText: submission.analysis.problemText,
      imageName: submission.imageName,
    });

    if (!listTitle || listTitle === "풀이 분석") continue;

    updated += 1;
    console.log(`[submission] ${submission.id} → ${listTitle}`);

    ops.push({
      updateOne: {
        filter: { id: submission.id },
        update: { $set: { "analysis.listTitle": listTitle } },
      },
    });

    if (ops.length >= 25) await flushBulk(col, ops, options.dryRun);
  }

  await flushBulk(col, ops, options.dryRun);
  return { scanned, updated };
}

async function migrateFeedQueues(options: CliOptions) {
  const db = await getMongoDb();
  if (!db) throw new Error("MongoDB not configured");

  const bankCol = db.collection<Document>("problem_bank_items");
  const col = db.collection<Document>("user_feed_queues");
  const cursor = col.find({});

  let scanned = 0;
  let updated = 0;
  const ops: AnyBulkWriteOperation<Document>[] = [];

  for await (const doc of cursor) {
    if (scanned >= options.batchSize) break;
    scanned += 1;
    const queue = doc as unknown as UserFeedQueue;
    let changed = false;

    const items = await Promise.all(
      queue.items.map(async (item) => {
        const title = item.title?.trim();
        if (title) {
          return { ...item, promptPreview: "" };
        }

        const bank = await bankCol.findOne({ id: item.bankItemId });
        const bankTitle = normalizeListTitle(
          (bank as { title?: string } | null)?.title ?? item.concept,
        );
        if (!bankTitle) return item;

        changed = true;
        return {
          ...item,
          title: bankTitle,
          promptPreview: "",
        };
      }),
    );

    if (!changed) continue;
    updated += 1;
    console.log(`[feed] ${queue.userId} → ${items.length} items`);

    ops.push({
      updateOne: {
        filter: { userId: queue.userId },
        update: { $set: { items } },
      },
    });

    if (ops.length >= 10) await flushBulk(col, ops, options.dryRun);
  }

  await flushBulk(col, ops, options.dryRun);
  return { scanned, updated };
}

async function main() {
  const options = parseArgs(process.argv.slice(2));
  console.log(
    `list-title migration (target=${options.target}, dryRun=${options.dryRun}, batch=${options.batchSize})`,
  );

  let scanned = 0;
  let updated = 0;

  if (options.target === "submissions" || options.target === "all") {
    const result = await migrateSubmissions(options);
    scanned += result.scanned;
    updated += result.updated;
  }

  if (options.target === "feed" || options.target === "all") {
    const result = await migrateFeedQueues(options);
    scanned += result.scanned;
    updated += result.updated;
  }

  console.log(`done: scanned=${scanned} updated=${updated}`);
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
