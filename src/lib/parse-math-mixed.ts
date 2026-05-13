/**
 * LLM 출력용 혼합 수식 규격:
 * - 블록: $$...$$ 또는 \[...\]
 * - 인라인: $...$ 또는 \(...\)  (통계 차트 레이블 등과 겹치지 않게 문제·해설에는 $를 수식 구분자로만 씀)
 */
export type MathMixedSegment =
  | { kind: "text"; value: string }
  | { kind: "inline"; latex: string }
  | { kind: "block"; latex: string };

function indexOfDoubleDollar(source: string, from: number): number {
  return source.indexOf("$$", from);
}

/** `$$` 짝의 시작이 아닌 단일 `$` */
function indexOfSingleDollar(source: string, from: number): number {
  let i = source.indexOf("$", from);
  while (i >= 0) {
    if (source[i + 1] !== "$") {
      return i;
    }
    i = source.indexOf("$", i + 2);
  }
  return -1;
}

function closingSingleDollar(source: string, from: number): number {
  let i = source.indexOf("$", from);
  while (i >= 0) {
    if (source[i + 1] !== "$") {
      return i;
    }
    i = source.indexOf("$", i + 2);
  }
  return -1;
}

type DelimKind = "$$" | "$" | "bracket" | "paren";

function pickNextDelimiter(source: string, pos: number): {
  kind: DelimKind;
  start: number;
} | null {
  const cand: { kind: DelimKind; start: number }[] = [];

  const iDd = indexOfDoubleDollar(source, pos);
  if (iDd >= 0) cand.push({ kind: "$$", start: iDd });

  const iSd = indexOfSingleDollar(source, pos);
  if (iSd >= 0) cand.push({ kind: "$", start: iSd });

  const iBr = source.indexOf("\\[", pos);
  if (iBr >= 0) cand.push({ kind: "bracket", start: iBr });

  const iPa = source.indexOf("\\(", pos);
  if (iPa >= 0) cand.push({ kind: "paren", start: iPa });

  if (cand.length === 0) {
    return null;
  }

  const minStart = Math.min(...cand.map((c) => c.start));
  const ties = cand.filter((c) => c.start === minStart);
  // 같은 위치에 `$$`와 `$` 동시 발생 불가(`$$`가 먼저 잡히면 단일 후보 아님)
  const prio: DelimKind[] = ["$$", "bracket", "paren", "$"];
  for (const p of prio) {
    const hit = ties.find((t) => t.kind === p);
    if (hit) {
      return hit;
    }
  }
  return ties[0] ?? null;
}

export function parseMathMixed(source: string): MathMixedSegment[] {
  if (!source) {
    return [{ kind: "text", value: "" }];
  }

  const out: MathMixedSegment[] = [];
  let pos = 0;

  while (pos < source.length) {
    const next = pickNextDelimiter(source, pos);

    if (next === null) {
      out.push({ kind: "text", value: source.slice(pos) });
      break;
    }

    if (next.start > pos) {
      out.push({ kind: "text", value: source.slice(pos, next.start) });
    }

    if (next.kind === "$$") {
      const open = next.start + 2;
      const close = indexOfDoubleDollar(source, open);
      if (close < 0) {
        out.push({ kind: "text", value: source.slice(next.start) });
        break;
      }
      out.push({
        kind: "block",
        latex: source.slice(open, close).trim(),
      });
      pos = close + 2;
      continue;
    }

    if (next.kind === "$") {
      const open = next.start + 1;
      const close = closingSingleDollar(source, open);
      if (close < 0) {
        out.push({ kind: "text", value: source.slice(next.start) });
        break;
      }
      out.push({
        kind: "inline",
        latex: source.slice(open, close).trim(),
      });
      pos = close + 1;
      continue;
    }

    if (next.kind === "bracket") {
      const open = next.start + 2;
      const close = source.indexOf("\\]", open);
      if (close < 0) {
        out.push({ kind: "text", value: source.slice(next.start) });
        break;
      }
      out.push({
        kind: "block",
        latex: source.slice(open, close).trim(),
      });
      pos = close + 2;
      continue;
    }

    // paren \(...\)
    const open = next.start + 2;
    const close = source.indexOf("\\)", open);
    if (close < 0) {
      out.push({ kind: "text", value: source.slice(next.start) });
      break;
    }
    out.push({
      kind: "inline",
      latex: source.slice(open, close).trim(),
    });
    pos = close + 2;
  }

  return out.length === 0 ? [{ kind: "text", value: source }] : out;
}
