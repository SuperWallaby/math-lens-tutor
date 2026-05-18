/** `/api/analyze` 진행 이벤트 `step` 값 */
export type AnalyzeProgressStep =
  | "upload"
  | "vision"
  | "tutor"
  | "similar"
  | "save";

const LABELS: Record<AnalyzeProgressStep, string> = {
  upload: "사진 읽는 중…",
  vision: "사진에서 문제 읽는 중…",
  tutor: "풀이 중…",
  similar: "유사 문제 만드는 중…",
  save: "결과 저장 중…",
};

/** 병렬 시 유사문제보다 풀이(tutor) 문구가 우선 */
export const ANALYZE_PROGRESS_RANK: Record<AnalyzeProgressStep, number> = {
  upload: 1,
  vision: 2,
  similar: 2,
  tutor: 3,
  save: 4,
};

export function analyzeProgressMessage(step: AnalyzeProgressStep): string {
  return LABELS[step];
}

export function shouldAdvanceProgressStep(
  current: AnalyzeProgressStep | null,
  next: AnalyzeProgressStep,
  options?: { tutorComplete?: boolean },
): boolean {
  if (!current) return true;
  // 병렬 중: 풀이(tutor) 문구 유지
  if (next === "similar" && current === "tutor" && !options?.tutorComplete) {
    return false;
  }
  // 풀이 끝난 뒤 유사문제가 아직이면 문구 전환
  if (next === "similar" && current === "tutor" && options?.tutorComplete) {
    return true;
  }
  return ANALYZE_PROGRESS_RANK[next] >= ANALYZE_PROGRESS_RANK[current];
}

export type AnalyzeProgressEvent = {
  type: "progress";
  step: AnalyzeProgressStep;
  message: string;
};

export function makeAnalyzeProgressEvent(
  step: AnalyzeProgressStep,
): AnalyzeProgressEvent {
  return {
    type: "progress",
    step,
    message: analyzeProgressMessage(step),
  };
}
