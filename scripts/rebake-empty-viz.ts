#!/usr/bin/env node
/**
 * 빈 그래프 PNG(contentHash)만 골라 rebake
 *
 *   npm run rebake:empty-viz
 *   npm run rebake:empty-viz -- --dry-run
 *   npm run rebake:empty-viz -- --target bank
 */
import { readFile } from "fs/promises";
import { readdir } from "fs/promises";
import { join } from "path";
import type { AnyBulkWriteOperation, Document } from "mongodb";

import { getMongoDb } from "../src/lib/mongodb";
import {
  enrichGeneratedProblemWithVisualization,
  migrateBankItemVisualization,
  withVisualizationBaker,
} from "../src/lib/visualization-generator";
import { pngLikelyEmptyGraph } from "../src/lib/viz-png-empty";
import type { GeneratedProblem, ProblemBankItem, GeneratedProblemSet } from "../src/lib/types";
import type { VisualizationData } from "../src/lib/visualization-schema";

type Target = "bank" | "sets" | "all";

function parseArgs(argv: string[]) {
  let target: Target = "all";
  const targetFlag = argv.indexOf("--target");
  if (targetFlag >= 0) {
    const value = argv[targetFlag + 1];
    if (value === "bank" || value === "sets" || value === "all") target = value;
  }
  return {
    dryRun: argv.includes("--dry-run"),
    target,
  };
}

function contentHashFromViz(viz: VisualizationData | null | undefined): string | null {
  const hash = viz?.data?.contentHash;
  return typeof hash === "string" && hash.trim() ? hash.trim() : null;
}

function problemUsesEmptyHash(
  problem: GeneratedProblem,
  emptyHashes: Set<string>,
): boolean {
  const promptHash = contentHashFromViz(problem.visualizationData);
  const solutionHash = contentHashFromViz(problem.solutionVisualizationData);
  return (
    (promptHash !== null && emptyHashes.has(promptHash)) ||
    (solutionHash !== null && emptyHashes.has(solutionHash))
  );
}

async function scanEmptyHashes(): Promise<Set<string>> {
  const vizDir = join(process.cwd(), "public/viz");
  const files = (await readdir(vizDir)).filter((name) => name.endsWith(".png"));
  const empty = new Set<string>();

  for (const file of files) {
    const hash = file.replace(/\.png$/i, "");
    const png = await readFile(join(vizDir, file));
    if (await pngLikelyEmptyGraph(png)) empty.add(hash);
  }

  return empty;
}

async function rebakeBank(emptyHashes: Set<string>, dryRun: boolean) {
  const db = await getMongoDb();
  if (!db) throw new Error("MongoDB not configured");
  const col = db.collection<Document>("problem_bank_items");

  const items = await col
    .find(
      {
        active: true,
        $or: [
          { "visualizationData.data.contentHash": { $in: [...emptyHashes] } },
          { "solutionVisualizationData.data.contentHash": { $in: [...emptyHashes] } },
        ],
      },
      { projection: { id: 1 } },
    )
    .toArray();

  let rebaked = 0;
  let failed = 0;
  const ops: AnyBulkWriteOperation<Document>[] = [];

  for (const row of items) {
    const id = row.id as string;
    const doc = await col.findOne({ id });
    if (!doc) continue;
    const item = doc as unknown as ProblemBankItem;

    console.log(`[rebake bank] ${item.id} · ${item.title}`);

    if (dryRun) {
      rebaked += 1;
      continue;
    }

    await col.updateOne({ id }, { $set: { visualizationMigrationStatus: "processing" } });

    const next = await migrateBankItemVisualization(item, { rebake: true });

    if (next.visualizationMigrationStatus === "completed") {
      rebaked += 1;
      console.log(`  → ok (${next.visualizationData?.type ?? "none"})`);
    } else {
      failed += 1;
      console.log(`  → fail: ${next.visualizationMigrationError ?? "unknown"}`);
    }

    ops.push({
      updateOne: {
        filter: { id },
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
  }

  if (!dryRun && ops.length > 0) await col.bulkWrite(ops, { ordered: false });
  return { matched: items.length, rebaked, failed };
}

async function rebakeSets(emptyHashes: Set<string>, dryRun: boolean) {
  const db = await getMongoDb();
  if (!db) throw new Error("MongoDB not configured");
  const col = db.collection<Document>("generated_problem_sets");

  const sets = await col
    .find(
      {
        $or: [
          { "problems.visualizationData.data.contentHash": { $in: [...emptyHashes] } },
          {
            "problems.solutionVisualizationData.data.contentHash": {
              $in: [...emptyHashes],
            },
          },
        ],
      },
      { projection: { id: 1 } },
    )
    .toArray();

  let matchedProblems = 0;
  let rebakedProblems = 0;
  let failedProblems = 0;
  const ops: AnyBulkWriteOperation<Document>[] = [];

  for (const row of sets) {
    const id = row.id as string;
    const doc = await col.findOne({ id });
    if (!doc) continue;
    const set = doc as unknown as GeneratedProblemSet;

    const needsRebake = set.problems.some((p) => problemUsesEmptyHash(p, emptyHashes));
    if (!needsRebake) continue;

    matchedProblems += set.problems.filter((p) => problemUsesEmptyHash(p, emptyHashes)).length;
    console.log(`[rebake set] ${set.id} · ${set.title}`);

    if (dryRun) {
      rebakedProblems += set.problems.filter((p) => problemUsesEmptyHash(p, emptyHashes)).length;
      continue;
    }

    const problems: GeneratedProblem[] = [];
    for (const problem of set.problems) {
      if (!problemUsesEmptyHash(problem, emptyHashes)) {
        problems.push(problem);
        continue;
      }
      const next = await enrichGeneratedProblemWithVisualization(problem, { rebake: true });
      problems.push(next);
      if (next.visualizationMigrationStatus === "completed") {
        rebakedProblems += 1;
        console.log(`  → ok problem ${problem.id}`);
      } else {
        failedProblems += 1;
        console.log(
          `  → fail problem ${problem.id}: ${next.visualizationMigrationError ?? "unknown"}`,
        );
      }
    }

    ops.push({
      updateOne: {
        filter: { id: set.id },
        update: { $set: { problems } },
      },
    });
  }

  if (!dryRun && ops.length > 0) await col.bulkWrite(ops, { ordered: false });
  return { matchedSets: sets.length, matchedProblems, rebakedProblems, failedProblems };
}

async function main() {
  const options = parseArgs(process.argv.slice(2));
  const emptyHashes = await scanEmptyHashes();

  console.log(
    `empty PNG hashes: ${emptyHashes.size}${options.dryRun ? " (dry-run)" : ""}`,
  );
  if (emptyHashes.size === 0) {
    console.log("nothing to rebake");
    return;
  }

  console.log([...emptyHashes].slice(0, 20).join(", ") + (emptyHashes.size > 20 ? " …" : ""));

  await withVisualizationBaker(async () => {
    if (options.target === "bank" || options.target === "all") {
      const bank = await rebakeBank(emptyHashes, options.dryRun);
      console.log("bank", bank);
    }
    if (options.target === "sets" || options.target === "all") {
      const sets = await rebakeSets(emptyHashes, options.dryRun);
      console.log("sets", sets);
    }
  });
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
