import { buildTrainingFocusItems } from "../src/lib/concept-training";
import {
  getPracticeMistakesForUser,
  getScannedProblemsForUser,
} from "../src/lib/problem-bank-store";
import { getAttempts, getSubmissionsByUserId } from "../src/lib/store";
import { buildFallbackFeedItems, refreshUserFeedQueue } from "../src/lib/training-feed";
import { getUserFeedQueue } from "../src/lib/training-feed-store";

async function main() {
  const userId =
    process.argv[2] ??
    "device:device_1780835765989_d5390a04e342ae2ead25d4b6a347b480";

  const [attempts, submissions, mistakes, scanned] = await Promise.all([
    getAttempts(userId),
    getSubmissionsByUserId(userId, 30),
    getPracticeMistakesForUser(userId),
    getScannedProblemsForUser(userId),
  ]);

  const focus = buildTrainingFocusItems({ mistakes, scanned, submissions });
  console.log({
    userId,
    attempts: attempts.length,
    mistakes: mistakes.length,
    scanned: scanned.length,
    focus: focus.slice(0, 5),
  });

  const fallback = await buildFallbackFeedItems({ userId, limit: 5 });
  console.log("fallback items:", fallback.length, fallback[0]?.concept);

  const db = await (await import("../src/lib/mongodb")).getMongoDb();
  const bankCount = await db!.collection("problem_bank_items").countDocuments({ active: true });
  console.log("active bank items:", bankCount);

  const queue = await refreshUserFeedQueue(userId);
  console.log("refreshed queue:", queue.items.length, queue.source);
  if (queue.items[0]) {
    console.log("sample reason:", queue.items[0].reason);
  }

  const saved = await getUserFeedQueue(userId);
  console.log("saved queue items:", saved?.items.length);
}

main().catch(console.error);
