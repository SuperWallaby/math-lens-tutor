import { NextResponse } from "next/server";
import { z } from "zod";

import { DEV_ACCOUNTS } from "@/lib/dev-accounts";
import { isDevEnvironment } from "@/lib/is-dev";

export async function GET() {
  if (!isDevEnvironment()) {
    return NextResponse.json({ error: "Not found" }, { status: 404 });
  }

  return NextResponse.json({
    accounts: DEV_ACCOUNTS.map((account) => ({
      id: account.id,
      label: account.label,
      displayName: account.displayName,
    })),
  });
}
