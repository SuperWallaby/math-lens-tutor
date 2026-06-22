#!/usr/bin/env node
/**
 * Remove invalid `choices: null` on free_response items (Zod rejects null).
 *
 *   npm run migrate:null-choices
 *   npm run migrate:null-choices -- --dry-run
 */
import type { Collection, Document } from "mongodb";

import { getMongoDb } from "../src/lib/mongodb";
import type { GeneratedProblem } from "../src/lib/types";

function parseArgs(argv: string[]) {
  return { dryRun: argv.includes("--dry-run") };
}

async function cleanBank(dryRun: boolean) {
  const db = await getMongoDb();
  if (!db) throw new Error("MongoDB not configured");

  const col = db.collection("problem_bank_items");
  const cursor = col.find({
    type: "free_response",
    choices: { $in: [null, []] },
  });

  let count = 0;
  for await (const doc of cursor) {
    count += 1;
    console.log(`[bank] unset choices · ${doc.id} · ${doc.title}`);
    if (!dryRun) {
      await col.updateOne({ id: doc.id }, { $unset: { choices: "" } });
    }
  }
  return count;
}

async function cleanProblemSets(dryRun: boolean) {
  const db = await getMongoDb();
  if (!db) throw new Error("MongoDB not configured");

  const col = db.collection("generated_problem_sets") as Collection<Document>;
  let scanned = 0;
  let updated = 0;

  for await (const doc of col.find({})) {
    scanned += 1;
    const problems = Array.isArray(doc.problems) ? doc.problems : [];
    let changed = false;

    const nextProblems = problems.map((raw: GeneratedProblem) => {
      const stripChoices =
        raw.choices === null ||
        (raw.type === "free_response" && raw.choices != null);
      if (!stripChoices) return raw;
      changed = true;
      const { choices: _drop, ...rest } = raw;
      return rest as GeneratedProblem;
    });

    if (!changed) continue;
    updated += 1;
    console.log(`[set] ${doc.id} · stripped null choices`);
    if (!dryRun) {
      await col.updateOne({ id: doc.id }, { $set: { problems: nextProblems } });
    }
  }

  return { scanned, updated };
}

async function main() {
  const { dryRun } = parseArgs(process.argv.slice(2));
  console.log(`null-choices migration (dryRun=${dryRun})`);

  const bank = await cleanBank(dryRun);
  console.log(`problem_bank_items: cleaned=${bank}`);

  const sets = await cleanProblemSets(dryRun);
  console.log(
    `generated_problem_sets: scanned=${sets.scanned} updated=${sets.updated}`,
  );

  if (dryRun) console.log("\nApply: npm run migrate:null-choices");
  else console.log("\nDone.");
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
