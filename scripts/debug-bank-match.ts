import { gradeToBand } from "../src/lib/curriculum";
import { findAvailableBankItems, getDeliveredBankItemIds } from "../src/lib/problem-bank-store";
import { findUserById } from "../src/lib/users";

const userId =
  process.argv[2] ??
  "device:device_1780835765989_d5390a04e342ae2ead25d4b6a347b480";

async function main() {
  const user = await findUserById(userId);
  const gradeBand = gradeToBand(user?.grade);
  const delivered = await getDeliveredBankItemIds(userId);
  console.log({ userId, grade: user?.grade, gradeBand, deliveredCount: delivered.size });

  for (const concept of ["합성수", "최소공배수", "약수"]) {
    const items = await findAvailableBankItems({
      userId,
      gradeBand,
      conceptTags: [concept],
      limit: 3,
    });
    console.log(concept, "=>", items.length, items[0]?.conceptPrimary);
  }

  const broad = await findAvailableBankItems({
    userId,
    gradeBand,
    conceptTags: ["합성수", "최소공배수", "약수"],
    limit: 5,
  });
  console.log("broad =>", broad.length);
}

main().catch(console.error);
