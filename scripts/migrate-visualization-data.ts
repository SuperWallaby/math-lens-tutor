#!/usr/bin/env node
/**
 * visualization_data 배치 마이그레이션
 *
 *   npm run migrate:visualization
 *   npm run migrate:visualization -- --dry-run
 *   npm run migrate:visualization -- --target sets
 *   npm run migrate:visualization -- --target all
 *   npm run migrate:visualization -- --only failed
 *   npm run migrate:visualization -- --id <bank-item-id|set-id>
 *   npm run migrate:visualization -- --batch-size 10
 *   npm run migrate:visualization -- --all
 */
import type { AnyBulkWriteOperation, Collection, Document } from "mongodb";

import { getMongoDb } from "../src/lib/mongodb";
import {
  migrateBankItemVisualization,
  migrateGeneratedProblemSet,
} from "../src/lib/visualization-generator";
import type {
  GeneratedProblemSet,
  ProblemBankItem,
  VisualizationMigrationStatus,
} from "../src/lib/types";

type MigrationTarget = "bank" | "sets" | "all";

type CliOptions = {
  dryRun: boolean;
  batchSize: number;
  only: VisualizationMigrationStatus | "all";
  id?: string;
  target: MigrationTarget;
};

function parseArgs(argv: string[]): CliOptions {
  const idFlag = argv.findIndex((a) => a === "--id");
  const batchFlag = argv.findIndex((a) => a === "--batch-size");
  const onlyFlag = argv.findIndex((a) => a === "--only");
  const targetFlag = argv.findIndex((a) => a === "--target");

  let only: CliOptions["only"] = "all";
  if (onlyFlag >= 0) {
    const value = argv[onlyFlag + 1] as VisualizationMigrationStatus | undefined;
    if (value === "pending" || value === "failed" || value === "completed") {
      only = value;
    }
  }

  let target: MigrationTarget = "all";
  if (targetFlag >= 0) {
    const value = argv[targetFlag + 1];
    if (value === "bank" || value === "sets" || value === "all") {
      target = value;
    }
  }

  return {
    dryRun: argv.includes("--dry-run"),
    batchSize: argv.includes("--all")
      ? Number.POSITIVE_INFINITY
      : batchFlag >= 0
        ? Number(argv[batchFlag + 1]) || 20
        : 20,
    only,
    id: idFlag >= 0 ? argv[idFlag + 1] : undefined,
    target,
  };
}

function buildBankFilter(options: CliOptions): Document {
  if (options.id) return { id: options.id, active: true };
  if (options.only === "all") {
    return {
      active: true,
      $or: [
        { visualizationMigrationStatus: { $exists: false } },
        { visualizationMigrationStatus: "pending" },
        { visualizationMigrationStatus: "failed" },
      ],
    };
  }
  return { active: true, visualizationMigrationStatus: options.only };
}

function buildSetFilter(options: CliOptions): Document {
  if (options.id) return { id: options.id };
  if (options.only === "all") {
    return {
      $or: [
        { "problems.visualizationMigrationStatus": { $exists: false } },
        { "problems.visualizationMigrationStatus": "pending" },
        { "problems.visualizationMigrationStatus": "failed" },
        {
          problems: {
            $elemMatch: {
              visualizationData: null,
              $or: [
                { "chart.type": { $exists: true } },
                { "jsxGraph.diagramNeeded": true },
              ],
            },
          },
        },
      ],
    };
  }
  return { "problems.visualizationMigrationStatus": options.only };
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

async function migrateBankItems(options: CliOptions) {
  const db = await getMongoDb();
  if (!db) throw new Error("MongoDB not configured");

  const col = db.collection<Document>("problem_bank_items");
  const filter = buildBankFilter(options);
  const cursor = col.find(filter);

  let scanned = 0;
  let completed = 0;
  let failed = 0;
  const ops: AnyBulkWriteOperation<Document>[] = [];

  for await (const doc of cursor) {
    if (!options.id && scanned >= options.batchSize) break;
    scanned += 1;
    const item = doc as unknown as ProblemBankItem;

    if (!options.dryRun) {
      await col.updateOne(
        { id: item.id },
        { $set: { visualizationMigrationStatus: "processing" } },
      );
    }

    const next = await migrateBankItemVisualization(item);

    if (next.visualizationMigrationStatus === "completed") {
      completed += 1;
      console.log(
        `[bank ok] ${item.id} · ${item.title} → ${
          next.visualizationData?.type ?? "none"
        }`,
      );
    } else {
      failed += 1;
      console.log(
        `[bank fail] ${item.id} · ${item.title}: ${next.visualizationMigrationError ?? "unknown"}`,
      );
    }

    ops.push({
      updateOne: {
        filter: { id: item.id },
        update: {
          $set: {
            visualizationData: next.visualizationData,
            solutionVisualizationData: next.solutionVisualizationData,
            visualizationMigrationStatus: next.visualizationMigrationStatus,
            visualizationMigrationError: next.visualizationMigrationError ?? null,
          },
        },
      },
    });

    if (ops.length >= 25) await flushBulk(col, ops, options.dryRun);
  }

  await flushBulk(col, ops, options.dryRun);
  return { scanned, completed, failed };
}

async function migrateProblemSets(options: CliOptions) {
  const db = await getMongoDb();
  if (!db) throw new Error("MongoDB not configured");

  const col = db.collection<Document>("generated_problem_sets");
  const filter = buildSetFilter(options);
  const cursor = col.find(filter);

  let scanned = 0;
  let completedProblems = 0;
  let failedProblems = 0;
  const ops: AnyBulkWriteOperation<Document>[] = [];

  for await (const doc of cursor) {
    if (!options.id && scanned >= options.batchSize) break;
    scanned += 1;
    const set = doc as unknown as GeneratedProblemSet;

    const problems = await migrateGeneratedProblemSet(set);

    for (const problem of problems) {
      if (problem.visualizationMigrationStatus === "completed") {
        completedProblems += 1;
      } else if (problem.visualizationMigrationStatus === "failed") {
        failedProblems += 1;
      }
    }

    console.log(
      `[sets ok] ${set.id} · ${set.title} → ${problems.filter((p) => p.visualizationData).length}/${problems.length} with viz`,
    );

    ops.push({
      updateOne: {
        filter: { id: set.id },
        update: { $set: { problems } },
      },
    });

    if (ops.length >= 10) await flushBulk(col, ops, options.dryRun);
  }

  await flushBulk(col, ops, options.dryRun);
  return { scanned, completed: completedProblems, failed: failedProblems };
}

async function main() {
  const options = parseArgs(process.argv.slice(2));
  console.log(
    `visualization migration (target=${options.target}, dryRun=${options.dryRun}, batch=${Number.isFinite(options.batchSize) ? options.batchSize : "all"}, only=${options.only})`,
  );

  let totalScanned = 0;
  let totalCompleted = 0;
  let totalFailed = 0;

  if (options.target === "bank" || options.target === "all") {
    const bank = await migrateBankItems(options);
    totalScanned += bank.scanned;
    totalCompleted += bank.completed;
    totalFailed += bank.failed;
  }

  if (options.target === "sets" || options.target === "all") {
    const sets = await migrateProblemSets(options);
    totalScanned += sets.scanned;
    totalCompleted += sets.completed;
    totalFailed += sets.failed;
  }

  console.log(
    `done: scanned=${totalScanned} completed=${totalCompleted} failed=${totalFailed}`,
  );

  if (options.dryRun) {
    console.log("\nApply: npm run migrate:visualization");
  }
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
