#!/usr/bin/env node
import { getMongoDb } from "../src/lib/mongodb";
import { visualizationContentHash } from "../src/lib/visualization-baker";
import type { VisualizationData } from "../src/lib/visualization-schema";

const targets = new Set(process.argv.slice(2));
const scanAll = targets.size === 0;

function maybeReport(
  source: string,
  id: string,
  field: string,
  viz: VisualizationData,
) {
  if (!viz) return;
  const hash =
    (typeof viz.data?.contentHash === "string" ? viz.data.contentHash.trim() : "") ||
    visualizationContentHash(viz);
  if (!scanAll && !targets.has(hash)) return;
  console.log(
    JSON.stringify({
      source,
      id,
      field,
      hash,
      type: viz.type,
      engine: viz.engine,
      data: viz.data,
    }),
  );
}

async function main() {
  const db = await getMongoDb();
  if (!db) {
    console.error("no mongo");
    process.exit(1);
  }

  if (!scanAll) {
    for (const hash of targets) {
      const bank = await db.collection("problem_bank_items").find({
        $or: [
          { "visualizationData.data.contentHash": hash },
          { "solutionVisualizationData.data.contentHash": hash },
        ],
      }).toArray();
      for (const doc of bank) {
        maybeReport("problem_bank_items", doc.id as string, "visualizationData", doc.visualizationData);
        maybeReport("problem_bank_items", doc.id as string, "solutionVisualizationData", doc.solutionVisualizationData);
      }

      const sets = await db.collection("problem_sets").find({
        $or: [
          { "problems.visualizationData.data.contentHash": hash },
          { "problems.solutionVisualizationData.data.contentHash": hash },
        ],
      }).toArray();
      for (const doc of sets) {
        for (const p of doc.problems ?? []) {
          maybeReport("problem_sets", `${doc.id}/${p.id}`, "visualizationData", p.visualizationData);
          maybeReport("problem_sets", `${doc.id}/${p.id}`, "solutionVisualizationData", p.solutionVisualizationData);
        }
      }
    }
    return;
  }

  const bank = await db.collection("problem_bank_items").find({}, {
    projection: {
      id: 1,
      visualizationData: 1,
      solutionVisualizationData: 1,
    },
  });
  for await (const doc of bank) {
    maybeReport("problem_bank_items", doc.id as string, "visualizationData", doc.visualizationData);
    maybeReport("problem_bank_items", doc.id as string, "solutionVisualizationData", doc.solutionVisualizationData);
  }
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
