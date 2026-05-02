import { randomUUID } from "crypto";
import { getMongoDb } from "./mongodb";
import type { ApiErrorLog } from "./types";

export const GENERIC_ANALYZE_ERROR =
  "분석 중 문제가 발생했습니다. 잠시 후 다시 시도해 주세요.";
export const GENERIC_SUBMIT_ERROR =
  "답안 제출 중 문제가 발생했습니다. 잠시 후 다시 시도해 주세요.";
export const GENERIC_INSIGHT_ERROR =
  "학습 데이터를 불러오는 중 문제가 발생했습니다. 잠시 후 다시 시도해 주세요.";

export async function logApiError(params: {
  request: Request;
  route: string;
  userId: string;
  error: unknown;
}): Promise<string> {
  const id = randomUUID();
  const error = params.error instanceof Error ? params.error : undefined;
  const message =
    error?.message ??
    (typeof params.error === "string" ? params.error : "Unknown error");

  const log: ApiErrorLog = {
    id,
    route: params.route,
    method: params.request.method,
    userId: params.userId,
    message,
    name: error?.name,
    stack: error?.stack,
    url: params.request.url,
    userAgent: params.request.headers.get("user-agent") ?? undefined,
    createdAt: new Date().toISOString(),
  };

  try {
    const db = await getMongoDb();
    if (db) {
      await db.collection<ApiErrorLog>("api_error_logs").insertOne(log);
    } else {
      console.error("API error", log);
    }
  } catch (loggingError) {
    console.error("Failed to write API error log", loggingError, log);
  }

  return id;
}
