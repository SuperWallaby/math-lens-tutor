#!/usr/bin/env node
import { getMongoDb } from "../src/lib/mongodb";

const TARGET = process.argv[2];
if (!TARGET) {
  console.error("usage: find-hash-in-bank.ts <hash>");
  process.exit(1);
}

async function main() {
  const db = await getMongoDb();
  if (!db) throw new Error("no mongo");

  const cursor = db.collection("problem_bank_items").find(
    {
      $or: [
        { "visualizationData.data.contentHash": TARGET },
        { "solutionVisualizationData.data.contentHash": TARGET },
        { "visualizationData.data.imageUrl": { $regex: TARGET } },
        { "solutionVisualizationData.data.imageUrl": { $regex: TARGET } },
      ],
    },
    { projection: { id: 1, visualizationData: 1, solutionVisualizationData: 1 } },
  );

  let found = 0;
  for await (const doc of cursor) {
    found += 1;
    console.log(JSON.stringify(doc, null, 2));
  }

  if (!found) console.log("not found in problem_bank_items");

  const setCollections = ["generated_problem_sets", "problem_sets"] as const;
  for (const setCol of setCollections) {
    const sets = await db.collection(setCol).find(
      {
        $or: [
          { "problems.visualizationData.data.contentHash": TARGET },
          { "problems.solutionVisualizationData.data.contentHash": TARGET },
          { "problems.visualizationData.data.imageUrl": { $regex: TARGET } },
          { "problems.solutionVisualizationData.data.imageUrl": { $regex: TARGET } },
        ],
      },
      { projection: { id: 1, problems: 1 } },
    ).limit(5).toArray();

    for (const doc of sets) {
      for (const p of doc.problems ?? []) {
        for (const field of ["visualizationData", "solutionVisualizationData"] as const) {
          const viz = p[field];
          if (viz?.data?.contentHash === TARGET) {
            console.log(JSON.stringify({ setId: doc.id, problemId: p.id, field, viz }, null, 2));
          }
        }
      }
    }
  }
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
