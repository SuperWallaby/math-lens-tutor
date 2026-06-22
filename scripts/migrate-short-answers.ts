#!/usr/bin/env node
/**
 * Expression-style free_response -> short answer or multiple choice.
 *
 *   npm run migrate:short-answers
 *   npm run migrate:short-answers -- --dry-run
 */
import type { AnyBulkWriteOperation, Collection, Document } from "mongodb";

import { getMongoDb } from "../src/lib/mongodb";
import {
  needsShortAnswerRepair,
  repairProblemForShortInput,
} from "../src/lib/problem-answer-sanitize";
import type { GeneratedProblem, ProblemBankItem } from "../src/lib/types";

type CliOptions = { dryRun: boolean };

function parseArgs(argv: string[]): CliOptions {
  return { dryRun: argv.includes("--dry-run") };
}

function toGeneratedProblem(item: ProblemBankItem): GeneratedProblem {
  return {
    id: item.id,
    type: item.type,
    title: item.title,
    prompt: item.prompt,
    choices: item.choices,
    correctAnswer: item.correctAnswer,
    explanation: item.explanation,
    difficulty: item.difficulty,
    conceptTags: item.conceptTags,
    chart: item.chart,
    jsxGraph: item.jsxGraph,
    source: "bank",
    bankItemId: item.id,
  };
}

function bankItemFromProblem(
  item: ProblemBankItem,
  repaired: GeneratedProblem,
): ProblemBankItem {
  return {
    ...item,
    type: repaired.type,
    title: repaired.title,
    prompt: repaired.prompt,
    choices: repaired.choices,
    correctAnswer: repaired.correctAnswer,
    explanation: repaired.explanation,
    difficulty: repaired.difficulty,
    conceptTags: repaired.conceptTags,
    chart: repaired.chart,
    jsxGraph: repaired.jsxGraph,
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

async function migrateBankItems(dryRun: boolean) {
  const db = await getMongoDb();
  if (!db) throw new Error("MongoDB not configured");

  const col = db.collection<Document>("problem_bank_items");
  const cursor = col.find({ type: "free_response", active: true });
  let scanned = 0;
  let repaired = 0;
  let deactivated = 0;
  const ops: AnyBulkWriteOperation<Document>[] = [];

  for await (const item of cursor) {
    scanned += 1;
    const bankItem = item as unknown as ProblemBankItem;
    const asProblem = toGeneratedProblem(bankItem);
    if (!needsShortAnswerRepair(asProblem)) continue;

    const fixed = repairProblemForShortInput(asProblem);
    if (!fixed) {
      deactivated += 1;
      console.log(`[deactivate] ${item.id} · ${item.title}`);
      ops.push({
        updateOne: {
          filter: { id: item.id },
          update: { $set: { active: false } },
        },
      });
    } else {
      repaired += 1;
      const next = bankItemFromProblem(bankItem, fixed);
      console.log(
        `[repair] ${item.id} · ${item.title}: ${item.correctAnswer} -> ${next.correctAnswer} (${next.type})`,
      );
      const setFields: Record<string, unknown> = {
        type: next.type,
        title: next.title,
        prompt: next.prompt,
        correctAnswer: next.correctAnswer,
        explanation: next.explanation,
      };
      if (next.type === "multiple_choice" && next.choices) {
        setFields.choices = next.choices;
      }
      const unsetFields: Record<string, ""> = { answerFormat: "" };
      if (next.type !== "multiple_choice") {
        unsetFields.choices = "";
      }
      ops.push({
        updateOne: {
          filter: { id: item.id },
          update: {
            $set: setFields,
            $unset: unsetFields,
          },
        },
      });
    }

    if (ops.length >= 50) await flushBulk(col, ops, dryRun);
  }

  await flushBulk(col, ops, dryRun);
  return { scanned, repaired, deactivated };
}

async function migrateProblemSets(dryRun: boolean) {
  const db = await getMongoDb();
  if (!db) throw new Error("MongoDB not configured");

  const col = db.collection("generated_problem_sets");
  const cursor = col.find({});
  let scanned = 0;
  let updated = 0;
  const ops: AnyBulkWriteOperation<Document>[] = [];

  for await (const doc of cursor) {
    scanned += 1;
    const problems = Array.isArray(doc.problems) ? doc.problems : [];
    let changed = false;

    const nextProblems = problems.map((raw: GeneratedProblem) => {
      if (raw.type !== "free_response" || !needsShortAnswerRepair(raw)) {
        return raw;
      }
      const fixed = repairProblemForShortInput(raw);
      if (!fixed || JSON.stringify(fixed) === JSON.stringify(raw)) return raw;
      changed = true;
      console.log(
        `[set ${doc.id}] ${raw.title}: ${raw.correctAnswer} -> ${fixed.correctAnswer}`,
      );
      return fixed;
    });

    if (!changed) continue;
    updated += 1;
    ops.push({
      updateOne: {
        filter: { id: doc.id },
        update: { $set: { problems: nextProblems } },
      },
    });
    if (ops.length >= 30) await flushBulk(col, ops, dryRun);
  }

  await flushBulk(col, ops, dryRun);
  return { scanned, updated };
}

async function main() {
  const { dryRun } = parseArgs(process.argv.slice(2));
  console.log(`short-answer migration (dryRun=${dryRun})`);

  const bank = await migrateBankItems(dryRun);
  console.log(
    `problem_bank_items: scanned=${bank.scanned} repaired=${bank.repaired} deactivated=${bank.deactivated}`,
  );

  const sets = await migrateProblemSets(dryRun);
  console.log(
    `generated_problem_sets: scanned=${sets.scanned} updated=${sets.updated}`,
  );

  if (dryRun) console.log("\nApply: npm run migrate:short-answers");
  else console.log("\nDone.");
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
