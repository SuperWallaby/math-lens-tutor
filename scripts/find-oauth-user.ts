import { getMongoDb } from "../src/lib/mongodb";

async function main() {
  const db = await getMongoDb();
  if (!db) {
    console.error("MongoDB not configured");
    process.exit(1);
  }

  const email = process.argv[2]?.trim();
  const provider = process.argv[3]?.trim();

  const filter: Record<string, unknown> = {};
  if (email) {
    filter.$or = [
      { email: { $regex: email.replace(/[.*+?^${}()|[\]\\]/g, "\\$&"), $options: "i" } },
      { oauthSubject: email },
      { displayName: { $regex: email.replace(/[.*+?^${}()|[\]\\]/g, "\\$&"), $options: "i" } },
    ];
  }
  if (provider) {
    filter.oauthProvider = provider;
  }

  const users = await db.collection("users").find(filter).toArray();

  for (const u of users) {
    console.log({
      id: u.id,
      email: u.email,
      provider: u.oauthProvider,
      subject: u.oauthSubject,
      displayName: u.displayName,
      role: u.role,
      profileComplete: u.profileComplete,
    });
  }
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
