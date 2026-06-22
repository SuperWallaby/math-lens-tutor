import { getMongoDb } from "../src/lib/mongodb";
import { buildFallbackFeedItems } from "../src/lib/training-feed";

async function main() {
  const db = await getMongoDb();
  if (!db) throw new Error("no db");

  const userIds = await db
    .collection("practice_mistake_records")
    .aggregate<{ _id: string }>([{ $group: { _id: "$userId" } }])
    .toArray();

  for (const row of userIds) {
    const items = await buildFallbackFeedItems({ userId: row._id, limit: 1 });
    if (items.length > 0) {
      console.log("FOUND", row._id, items[0].concept);
      return;
    }
  }
  console.log("none found among", userIds.length, "users");
}

main().catch(console.error);
