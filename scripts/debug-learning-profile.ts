import { buildLearningProfile } from "../src/lib/learning-profile";
import { getMongoDb } from "../src/lib/mongodb";
import { toSubmissionListItem } from "../src/lib/submission-list";
import { getSubmissionsByUserId } from "../src/lib/store";

async function main() {
  const db = await getMongoDb();
  if (!db) throw new Error("MongoDB not configured");

  const users = await db
    .collection("users")
    .find({})
    .project({ id: 1, email: 1, role: 1, grade: 1 })
    .limit(50)
    .toArray();

  console.log(`users: ${users.length}`);

  for (const user of users) {
    const label = `${user.id} ${user.email ?? user.role ?? ""}`;
    try {
      await buildLearningProfile(user.id as string, (user.grade as string) ?? "중1");
      const subs = await getSubmissionsByUserId(user.id as string);
      for (const sub of subs) {
        toSubmissionListItem(sub);
      }
      console.log(`OK  ${label} submissions=${subs.length}`);
    } catch (error) {
      console.error(`FAIL ${label}`, error);
    }
  }
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
