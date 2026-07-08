#!/usr/bin/env node
import { getMongoDb } from "../src/lib/mongodb";

const TARGET = process.argv[2];
if (!TARGET) {
  console.error("usage: lookup-viz-hash.ts <hash>");
  process.exit(1);
}

async function main() {
  const db = await getMongoDb();
  if (!db) throw new Error("no mongo");

  const bank = await db
    .collection("problem_bank_items")
    .find(
      {
        $or: [
          { "visualizationData.data.contentHash": TARGET },
          { "solutionVisualizationData.data.contentHash": TARGET },
        ],
      },
      { projection: { id: 1, visualizationData: 1, solutionVisualizationData: 1 } },
    )
    .toArray();
  console.log("bank", JSON.stringify(bank, null, 2));

  const sets = await db
    .collection("problem_sets")
    .find(
      {
        $or: [
          { "problems.visualizationData.data.contentHash": TARGET },
          { "problems.solutionVisualizationData.data.contentHash": TARGET },
        ],
      },
      { projection: { id: 1, problems: 1 } },
    )
    .limit(5)
    .toArray();
  for (const doc of sets) {
    for (const p of doc.problems ?? []) {
      for (const field of ["visualizationData", "solutionVisualizationData"] as const) {
        const viz = p[field];
        if (viz?.data?.contentHash === TARGET) {
          console.log(
            "problem_set",
            JSON.stringify({ setId: doc.id, problemId: p.id, field, viz }, null, 2),
          );
        }
      }
    }
  }
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
