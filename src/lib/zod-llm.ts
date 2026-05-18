import { z } from "zod";

/** LLM JSON이 숫자·불리언으로보내는 필드를 문자열로 정규화 */
export function coerceLlmString(value: unknown): string {
  if (value === null || value === undefined) return "";
  if (typeof value === "number") {
    if (Number.isFinite(value) && Number.isInteger(value)) {
      return String(value);
    }
    return String(value);
  }
  if (typeof value === "boolean") return value ? "true" : "false";
  if (typeof value === "string") return value.trim();
  return String(value);
}

export function llmStringField() {
  return z.preprocess((val) => coerceLlmString(val), z.string());
}

/** confidence 등 — 숫자 문자열도 허용 */
export function llmConfidenceField() {
  return z.preprocess((val) => {
    if (typeof val === "number" && Number.isFinite(val)) return val;
    if (typeof val === "string") {
      const n = Number(val.trim());
      if (Number.isFinite(n)) return n;
    }
    return 0;
  }, z.number().min(0).max(1));
}
