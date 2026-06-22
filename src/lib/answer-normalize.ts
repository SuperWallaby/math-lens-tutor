/** `$24$`, `$$…$$` 등 LaTeX 구분자 제거 — 채점·피드백 표시용 */
export function stripMathDelimiters(text: string): string {
  return text
    .replace(/\$\$/g, "")
    .replace(/\$/g, "")
    .replace(/\\,/g, "")
    .trim();
}

/** 답안 비교용 정규화 (공백·유니코드 마이너스·LaTeX 구분자) */
export function normalizeAnswerForGrade(answer: string): string {
  return stripMathDelimiters(answer)
    .replace(/\s+/g, "")
    .replace(/\u2212/g, "-")
    .replace(/，/g, ",")
    .toLowerCase();
}

/** 오답 피드백 등 사람이 읽는 한 줄 답 */
export function formatAnswerForDisplay(answer: string): string {
  return stripMathDelimiters(answer);
}
