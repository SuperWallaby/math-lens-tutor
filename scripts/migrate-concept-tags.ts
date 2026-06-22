#!/usr/bin/env node
/**
 * conceptTags 를 최대 2개로 맞추는 DB 마이그레이션.
 *
 *   npm run migrate:concept-tags              # 적용
 *   npm run migrate:concept-tags -- --dry-run # 변경 미리보기만
 */
import type { AnyBulkWriteOperation, Collection, Document } from "mongodb";

import { getMongoDb } from "../src/lib/mongodb";
import { normalizeConceptTags } from "../src/lib/types";

type CliOptions = {
  dryRun: boolean;
  maxTags: number;
};

function parseArgs(argv: string[]): CliOptions {
  const opts: CliOptions = { dryRun: false, maxTags: 2 };
  for (const arg of argv) {
    if (arg === "--dry-run") opts.dryRun = true;
    if (arg.startsWith("--max=")) {
      opts.maxTags = Math.max(1, Number(arg.split("=")[1]) || 2);
    }
  }
  return opts;
}

function trimTags(tags: unknown, max: number): string[] {
  return normalizeConceptTags(tags, max);
}

function tagsNeedTrim(tags: unknown, max: number): boolean {
  if (!Array.isArray(tags)) return true;
  const normalized = tags
    .filter((t): t is string => typeof t === "string")
    .map((t) => t.trim())
    .filter(Boolean);
  return normalized.length === 0 || normalized.length > max;
}

async function flushBulk(
  col: Collection<Document>,
  ops: AnyBulkWriteOperation<Document>[],
  dryRun: boolean,
) {
  if (ops.length === 0) return;
  if (!dryRun) {
    await col.bulkWrite(ops, { ordered: false });
  }
  ops.length = 0;
}

async function migrateProblemBankItems(max: number, dryRun: boolean) {
  const db = await getMongoDb();
  if (!db) throw new Error("MongoDB 설정이 없습니다 (.env.local 확인).");

  const col = db.collection("problem_bank_items");
  const cursor = col.find({});
  let scanned = 0;
  let updated = 0;
  const ops: AnyBulkWriteOperation<Document>[] = [];

  for await (const doc of cursor) {
    scanned += 1;
    if (!tagsNeedTrim(doc.conceptTags, max)) continue;

    const conceptTags = trimTags(doc.conceptTags, max);
    const conceptPrimary = conceptTags[0] ?? String(doc.conceptPrimary ?? "수학 연습");
    updated += 1;
    ops.push({
      updateOne: {
        filter: { id: doc.id },
        update: { $set: { conceptTags, conceptPrimary } },
      },
    });

    if (ops.length >= 100) {
      await flushBulk(col, ops, dryRun);
    }
  }

  await flushBulk(col, ops, dryRun);
  return { scanned, updated };
}

async function migrateGeneratedProblemSets(max: number, dryRun: boolean) {
  const db = await getMongoDb();
  if (!db) throw new Error("MongoDB 설정이 없습니다.");

  const col = db.collection("generated_problem_sets");
  const cursor = col.find({});
  let scanned = 0;
  let updated = 0;
  const ops: AnyBulkWriteOperation<Document>[] = [];

  for await (const doc of cursor) {
    scanned += 1;
    const problems = Array.isArray(doc.problems) ? doc.problems : [];
    let changed = false;

    const nextProblems = problems.map((problem: Record<string, unknown>) => {
      if (!tagsNeedTrim(problem.conceptTags, max)) return problem;
      changed = true;
      return {
        ...problem,
        conceptTags: trimTags(problem.conceptTags, max),
      };
    });

    if (!changed) continue;

    updated += 1;
    ops.push({
      updateOne: {
        filter: { id: doc.id },
        update: { $set: { problems: nextProblems } },
      },
    });

    if (ops.length >= 50) {
      await flushBulk(col, ops, dryRun);
    }
  }

  await flushBulk(col, ops, dryRun);
  return { scanned, updated };
}

async function migrateTaggedRecords(
  collectionName: "scanned_problem_records" | "practice_mistake_records",
  max: number,
  dryRun: boolean,
) {
  const db = await getMongoDb();
  if (!db) throw new Error("MongoDB 설정이 없습니다.");

  const col = db.collection(collectionName);
  const cursor = col.find({});
  let scanned = 0;
  let updated = 0;
  const ops: AnyBulkWriteOperation<Document>[] = [];

  for await (const doc of cursor) {
    scanned += 1;
    if (!tagsNeedTrim(doc.conceptTags, max)) continue;

    const conceptTags = trimTags(doc.conceptTags, max);
    const conceptPrimary = conceptTags[0] ?? String(doc.conceptPrimary ?? "수학 연습");
    updated += 1;
    ops.push({
      updateOne: {
        filter: { id: doc.id },
        update: { $set: { conceptTags, conceptPrimary } },
      },
    });

    if (ops.length >= 100) {
      await flushBulk(col, ops, dryRun);
    }
  }

  await flushBulk(col, ops, dryRun);
  return { scanned, updated };
}

async function main() {
  const opts = parseArgs(process.argv.slice(2));

  console.log(
    `conceptTags 마이그레이션 (max=${opts.maxTags}, dryRun=${opts.dryRun})`,
  );

  const bank = await migrateProblemBankItems(opts.maxTags, opts.dryRun);
  console.log(
    `problem_bank_items: ${bank.updated}/${bank.scanned}건 ${opts.dryRun ? "변경 예정" : "업데이트"}`,
  );

  const sets = await migrateGeneratedProblemSets(opts.maxTags, opts.dryRun);
  console.log(
    `generated_problem_sets: ${sets.updated}/${sets.scanned}건 ${opts.dryRun ? "변경 예정" : "업데이트"}`,
  );

  const scanned = await migrateTaggedRecords(
    "scanned_problem_records",
    opts.maxTags,
    opts.dryRun,
  );
  console.log(
    `scanned_problem_records: ${scanned.updated}/${scanned.scanned}건 ${opts.dryRun ? "변경 예정" : "업데이트"}`,
  );

  const mistakes = await migrateTaggedRecords(
    "practice_mistake_records",
    opts.maxTags,
    opts.dryRun,
  );
  console.log(
    `practice_mistake_records: ${mistakes.updated}/${mistakes.scanned}건 ${opts.dryRun ? "변경 예정" : "업데이트"}`,
  );

  if (opts.dryRun) {
    console.log("\n실제 반영: npm run migrate:concept-tags");
  } else {
    console.log("\n완료.");
  }

  process.exit(0);
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
