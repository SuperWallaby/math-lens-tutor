import { softBreakAnswerExplanation } from "./soft-break-korean-math-text";

/** 한글·수식·문장부호가 붙어 나온 LLM 풀이 문자열을 읽기 쉽게 정리 */
export function insertHangulMathSpacing(input: string): string {
  let s = input;
  // 한글 ↔ $ … $
  s = s.replace(/([가-힣])(\$)/g, "$1 $2");
  s = s.replace(/(\$[^$\n]*\$)([가-힣])/g, "$1 $2");
  // 한글 ↔ 백슬래시 수식
  s = s.replace(/([가-힣])(\\[a-zA-Z])/g, "$1 $2");
  s = s.replace(
    /(\\(?:frac|sqrt|left|right|cdot|times|le|ge|ne|pm)[^가-힣]*?)([가-힣])/g,
    "$1 $2",
  );
  // 문장부호 뒤 한글
  s = s.replace(/([.!?,:;])([가-힣])/g, "$1 $2");
  // 닫는 괄호·따옴표 뒤 한글
  s = s.replace(/([)\]}>"'])([가-힣])/g, "$1 $2");
  return s.replace(/ {2,}/g, " ");
}

/** 한 줄로 이어진 단계 설명을 단락으로 나눔 */
export function softBreakSolutionStepText(input: string): string {
  const s = input.replace(/\r\n/g, "\n");
  if (!s.trim() || /\n/.test(s)) {
    return insertHangulMathSpacing(s);
  }

  let t = softBreakAnswerExplanation(s);
  if (/\n/.test(t)) {
    return insertHangulMathSpacing(t);
  }

  const breakers =
    /\s+(?=따라서|그러므로|그래서|또한|때문에|이때|이므로|정리하면|결과적으로|단계\s*\d|제\d|첫째|둘째|셋째|마지막으로|즉,|따라서\s*\$)/;
  const parts: string[] = [];
  let rest = t;
  let m: RegExpExecArray | null;
  const re = new RegExp(breakers.source, "g");
  let last = 0;
  while ((m = re.exec(rest)) !== null) {
    if (m.index > last) {
      parts.push(rest.slice(last, m.index).trimEnd());
    }
    last = m.index + m[0].length;
  }
  if (last < rest.length) {
    parts.push(rest.slice(last).trimStart());
  }
  if (parts.length > 1) {
    t = parts.filter(Boolean).join("\n\n");
  }

  return insertHangulMathSpacing(t);
}

export function formatReadableSolutionText(input: string): string {
  return softBreakSolutionStepText(input ?? "");
}
