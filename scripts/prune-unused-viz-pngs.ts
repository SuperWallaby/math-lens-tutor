#!/usr/bin/env node
/**
 * DB에서 참조하지 않는 viz PNG 삭제 (public/viz + flutter_app/web/viz)
 *
 *   npm run prune:viz-pngs -- --dry-run
 *   npm run prune:viz-pngs
 */
import { readFileSync, readdirSync, unlinkSync } from "fs";
import { join } from "path";

import { getMongoDb } from "../src/lib/mongodb";
import type { GeneratedProblem, GeneratedProblemSet, ProblemBankItem } from "../src/lib/types";

const PINNED_HASH_SOURCES = [
  join(process.cwd(), "flutter_app/lib/dev/design_review_data.dart"),
];

function parseArgs(argv: string[]) {
  return {
    dryRun: argv.includes("--dry-run"),
    verbose: argv.includes("--verbose"),
  };
}

function hashFromImageUrl(url: unknown): string | null {
  if (typeof url !== "string" || !url.trim()) return null;
  const match = url.trim().match(/\/viz\/([a-f0-9]{8,64})\.png/i);
  return match?.[1] ?? null;
}

function hashFromViz(viz: unknown): string | null {
  if (!viz || typeof viz !== "object") return null;
  const data = (viz as { data?: Record<string, unknown> }).data;
  if (!data) return null;

  const contentHash =
    typeof data.contentHash === "string" ? data.contentHash.trim() : "";
  if (contentHash) return contentHash;

  return hashFromImageUrl(data.imageUrl);
}

function collectFromProblem(problem: Pick<GeneratedProblem, "visualizationData" | "solutionVisualizationData">, used: Set<string>) {
  for (const field of [problem.visualizationData, problem.solutionVisualizationData]) {
    const hash = hashFromViz(field);
    if (hash) used.add(hash);
  }
}

function collectPinnedHashes(used: Set<string>) {
  for (const filePath of PINNED_HASH_SOURCES) {
    try {
      const text = readFileSync(filePath, "utf8");
      for (const match of text.matchAll(/\/viz\/([a-f0-9]{8,64})\.png/gi)) {
        if (match[1]) used.add(match[1]);
      }
      for (const match of text.matchAll(/contentHash['"]\s*:\s*['"]([a-f0-9]{8,64})['"]/gi)) {
        if (match[1]) used.add(match[1]);
      }
    } catch {
      /* optional source */
    }
  }
}

async function collectUsedHashesFromDb(): Promise<Set<string>> {
  const used = new Set<string>();
  collectPinnedHashes(used);

  const db = await getMongoDb();
  if (!db) {
    console.warn("MongoDB not configured — only pinned hashes kept");
    return used;
  }

  const bankItems = await db
    .collection<ProblemBankItem>("problem_bank_items")
    .find(
      {
        $or: [
          { visualizationData: { $ne: null } },
          { solutionVisualizationData: { $ne: null } },
        ],
      },
      { projection: { visualizationData: 1, solutionVisualizationData: 1 } },
    )
    .toArray();
  for (const item of bankItems) collectFromProblem(item, used);

  const setCollections = ["generated_problem_sets", "problem_sets"] as const;
  for (const colName of setCollections) {
    const sets = await db
      .collection<GeneratedProblemSet>(colName)
      .find(
        {
          $or: [
            { "problems.visualizationData": { $ne: null } },
            { "problems.solutionVisualizationData": { $ne: null } },
          ],
        },
        { projection: { problems: 1 } },
      )
      .toArray();
    for (const set of sets) {
      for (const problem of set.problems ?? []) collectFromProblem(problem, used);
    }
  }

  return used;
}

function listPngHashes(dir: string): string[] {
  try {
    return readdirSync(dir)
      .filter((name) => name.endsWith(".png"))
      .map((name) => name.replace(/\.png$/i, ""));
  } catch {
    return [];
  }
}

function pruneDir(dir: string, used: Set<string>, dryRun: boolean, verbose: boolean) {
  const hashes = listPngHashes(dir);
  let removed = 0;
  let kept = 0;

  for (const hash of hashes) {
    if (used.has(hash)) {
      kept += 1;
      continue;
    }
    const filePath = join(dir, `${hash}.png`);
    if (!dryRun) unlinkSync(filePath);
    removed += 1;
    if (verbose) {
      console.log(`${dryRun ? "[dry-run delete]" : "[deleted]"} ${filePath}`);
    }
  }

  return { total: hashes.length, kept, removed };
}

async function main() {
  const options = parseArgs(process.argv.slice(2));
  const used = await collectUsedHashesFromDb();

  const dirs = [
    join(process.cwd(), "public/viz"),
    join(process.cwd(), "flutter_app/web/viz"),
  ];

  console.log(`referenced hashes: ${used.size}${options.dryRun ? " (dry-run)" : ""}`);

  let totalRemoved = 0;
  let totalKept = 0;
  let totalFiles = 0;

  for (const dir of dirs) {
    const result = pruneDir(dir, used, options.dryRun, options.verbose);
    totalFiles += result.total;
    totalKept += result.kept;
    totalRemoved += result.removed;
    console.log(`${dir}: files=${result.total} keep=${result.kept} remove=${result.removed}`);
  }

  console.log(
    `\ndone: files=${totalFiles} keep=${totalKept} remove=${totalRemoved}${options.dryRun ? " (dry-run)" : ""}`,
  );
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
