export const ANALYZE_QUALITY_MODES = ["fast", "balanced", "accurate"] as const;

export type AnalyzeQualityMode = (typeof ANALYZE_QUALITY_MODES)[number];

export function parseAnalyzeQualityMode(raw: unknown): AnalyzeQualityMode {
  if (typeof raw !== "string") {
    return "balanced";
  }
  const s = raw.trim().toLowerCase();
  if (s === "fast" || s === "balanced" || s === "accurate") {
    return s;
  }
  return "balanced";
}
