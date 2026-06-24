#!/usr/bin/env node
/**
 * Strip duplicate "1. " / "①" prefixes from multiple-choice labels in DB.
 *
 *   npm run migrate:choice-labels
 *   npm run migrate:choice-labels -- --dry-run
 */
import type { AnyBulkWriteOperation, Collection, Document } from "mongodb";

import { normalizeMultipleChoiceProblem } from "../src/lib/choice-label-format";
import { env, hasMongoConfig } from "../src/lib/env";
import type { GeneratedProblem, ProblemBankItem } from "../src/lib/types";
import { MongoClient } from "mongodb";

type CliOptions = { dryRun: boolean };

function parseArgs(argv: string[]): CliOptions {
  return { dryRun: argv.includes("--dry-run") };
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

async function migrateBankItems(
  col: Collection<Document>,
  dryRun: boolean,
) {
  const cursor = col.find({ type: "multiple_choice", active: { $ne: false } });
  let scanned = 0;
  let updated = 0;
  const ops: AnyBulkWriteOperation<Document>[] = [];

  for await (const doc of cursor) {
    scanned += 1;
    const item = doc as unknown as ProblemBankItem;
    const { problem, changed } = normalizeMultipleChoiceProblem({
      type: item.type,
      correctAnswer: item.correctAnswer,
      choices: item.choices,
    });
    if (!changed) continue;

    updated += 1;
    console.log(`[bank] ${item.id} · ${item.title}`);
    ops.push({
      updateOne: {
        filter: { id: item.id },
        update: {
          $set: {
            choices: problem.choices,
            correctAnswer: problem.correctAnswer,
          },
        },
      },
    });
    if (ops.length >= 100) await flushBulk(col, ops, dryRun);
  }

  await flushBulk(col, ops, dryRun);
  return { scanned, updated };
}

async function migrateProblemSets(
  col: Collection<Document>,
  dryRun: boolean,
) {
  let scanned = 0;
  let updated = 0;

  for await (const doc of col.find({})) {
    scanned += 1;
    const problems = Array.isArray(doc.problems) ? doc.problems : [];
    let changed = false;

    const nextProblems = problems.map((raw: GeneratedProblem) => {
      const { problem, changed: itemChanged } =
        normalizeMultipleChoiceProblem(raw);
      if (itemChanged) changed = true;
      return problem;
    });

    if (!changed) continue;
    updated += 1;
    console.log(`[set] ${doc.id}`);
    if (!dryRun) {
      await col.updateOne({ id: doc.id }, { $set: { problems: nextProblems } });
    }
  }

  return { scanned, updated };
}

async function migrateDb(dbName: string, dryRun: boolean) {
  if (!hasMongoConfig() || !env.mongodbUri) {
    throw new Error("MongoDB not configured");
  }

  const client = new MongoClient(env.mongodbUri);
  await client.connect();
  const db = client.db(dbName);

  console.log(`\n=== ${dbName} ===`);

  const bank = await migrateBankItems(
    db.collection<Document>("problem_bank_items"),
    dryRun,
  );
  const sets = await migrateProblemSets(
    db.collection<Document>("generated_problem_sets"),
    dryRun,
  );

  await client.close();

  console.log(
    `problem_bank_items: scanned=${bank.scanned} updated=${bank.updated}`,
  );
  console.log(
    `generated_problem_sets: scanned=${sets.scanned} updated=${sets.updated}`,
  );

  return { bank, sets };
}

async function main() {
  const { dryRun } = parseArgs(process.argv.slice(2));
  console.log(`strip-choice-labels migration (dryRun=${dryRun})`);

  await migrateDb(env.mongodbDbName, dryRun);
  if (env.mongodbDbNameLite !== env.mongodbDbName) {
    await migrateDb(env.mongodbDbNameLite, dryRun);
  }

  if (dryRun) console.log("\nApply: npm run migrate:choice-labels");
  else console.log("\nDone.");
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
