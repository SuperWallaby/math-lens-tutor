import { appendFileSync } from "node:fs";
import { join } from "node:path";

export function agentDebugLog(payload: Record<string, unknown>): void {
  if (process.env.NODE_ENV === "production") return;
  try {
    const logPath =
      process.env.DEBUG_LOG_PATH ??
      join(process.cwd(), ".cursor", "debug-6366de.log");
    appendFileSync(
      logPath,
      JSON.stringify({
        sessionId: "6366de",
        timestamp: Date.now(),
        ...payload,
      }) + "\n",
      "utf8",
    );
  } catch {
    // ignore
  }
}
