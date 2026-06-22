import { getMongoDb } from "../src/lib/mongodb";

async function main() {
  const db = await getMongoDb();
  if (!db) throw new Error("no db");

  const concepts = await db
    .collection("problem_bank_items")
    .find({ active: true, conceptPrimary: /합성/ }, { projection: { conceptPrimary: 1, gradeBand: 1, _id: 0 } })
    .limit(5)
    .toArray();
  console.log("bank 합성 samples:", concepts);

  const tags = await db
    .collection("problem_bank_items")
    .find({ active: true, conceptTags: "약수" }, { projection: { conceptPrimary: 1, gradeBand: 1, _id: 0 } })
    .limit(3)
    .toArray();
  console.log("bank 약수 tag samples:", tags);
}

main().catch(console.error);
