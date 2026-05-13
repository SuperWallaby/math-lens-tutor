/**
 * 분석 JSON 등에서 모델이 `$` 없이 LaTeX를 섞어 줄 때 KaTeX가 동작하도록
 * `$…$` 를 삽입합니다.
 * 이미 `$`, `$$`, `\(`, `\[` 가 있으면 손대지 않습니다.
 */

/** `{` 시작 위치에서 짝 되는 `}` 직후 인덱스 */
function consumeBalancedBrace(s: string, openBrace: number): number {
  let depth = 1;
  let k = openBrace + 1;
  while (k < s.length && depth > 0) {
    const ch = s[k];
    if (ch === "{") depth++;
    else if (ch === "}") depth--;
    k++;
  }
  return k;
}

function skipSpaces(s: string, from: number): number {
  let k = from;
  while (k < s.length && /\s/.test(s[k]!)) k++;
  return k;
}

function tryParseFracAt(
  s: string,
  i: number,
): { full: string; end: number } | null {
  if (!s.startsWith("\\frac", i)) return null;
  let pos = skipSpaces(s, i + 5);
  if (s[pos] !== "{") return null;
  pos = consumeBalancedBrace(s, pos);
  pos = skipSpaces(s, pos);
  if (s[pos] !== "{") return null;
  pos = consumeBalancedBrace(s, pos);
  return { full: s.slice(i, pos), end: pos };
}

function tryParseSqrtAt(
  s: string,
  i: number,
): { full: string; end: number } | null {
  if (!s.startsWith("\\sqrt", i)) return null;
  let pos = skipSpaces(s, i + 5);
  if (s[pos] === "[") {
    const close = s.indexOf("]", pos + 1);
    if (close < 0) return null;
    pos = skipSpaces(s, close + 1);
  }
  if (s[pos] !== "{") return null;
  pos = consumeBalancedBrace(s, pos);
  return { full: s.slice(i, pos), end: pos };
}

/** `\frac`/`\sqrt`를 중첩 포함해 균형한 인자까지 한 덩어리로 감쌉니다 */
function wrapNestedConstructs(s: string): string {
  const stack: string[] = [];
  let pos = 0;
  while (pos < s.length) {
    if (s.startsWith("\\sqrt", pos)) {
      const p = tryParseSqrtAt(s, pos);
      if (p) {
        stack.push(p.full);
        pos = p.end;
        continue;
      }
    }
    if (s.startsWith("\\frac", pos)) {
      const p = tryParseFracAt(s, pos);
      if (p) {
        stack.push(p.full);
        pos = p.end;
        continue;
      }
    }
    pos++;
  }
  let t = s;
  for (const fragment of [...new Set(stack)].sort(
    (a, b) => b.length - a.length,
  )) {
    const wrapped = `$${fragment}$`;
    if (!fragment.includes("$")) {
      t = t.split(fragment).join(wrapped);
    }
  }
  return t;
}

/**
 * `\cos`, `\angle`, `\theta`, `QR=RS` 등 연속 LaTeX 친화 토큰을
 * 한 인라인 수식 블록으로 감쌉니다 (`$…$` 밖에서만).
 */
function consumeBareLatexRun(s: string, start: number): number {
  let j = start;
  while (j < s.length) {
    if (s[j] === "\\" && /[a-zA-Z]/i.test(s[j + 1] ?? "")) {
      j++;
      while (j < s.length && /[a-zA-Z]/i.test(s[j]!)) j++;
      if (s[j] === "*") j++;
      continue;
    }
    if (/\s/.test(s[j]!)) {
      const spStart = j;
      let sp = j;
      while (sp < s.length && /\s/.test(s[sp]!)) sp++;
      if (sp - spStart >= 2) break;
      if (sp < s.length && s[sp] === "\\") {
        j = sp;
        continue;
      }
      break;
    }
    const ch = s[j]!;
    // 한글·자모 시작이면 식 종료 ("…이므로 \angle BAC…"처럼 뒤에만 수식 있는 경우 처리)
    if (/[가-힣ㄱ-ㅎㅏ-ㅣ]/.test(ch)) break;
    if (/[0-9.]/.test(ch)) {
      while (j < s.length && /[0-9.]/.test(s[j]!)) j++;
      continue;
    }
    if (/[+\-=*/<>≠≤≥.(),;:!'|≈]/.test(ch)) {
      j++;
      continue;
    }
    if (/[A-Za-z]/.test(ch)) {
      while (j < s.length && /[A-Za-z]/.test(s[j]!)) j++;
      continue;
    }
    if (ch === "_" || ch === "^") {
      j++;
      if (s[j] === "{") {
        j = consumeBalancedBrace(s, j);
        continue;
      }
      if (/[0-9A-Za-z(]/.test(s[j] ?? "")) j++;
      continue;
    }
    if (ch === "{") {
      j = consumeBalancedBrace(s, j);
      continue;
    }
    break;
  }
  return j;
}

function wrapBackslashSequencesOutsideDelimiters(fragment: string): string {
  if (!fragment.includes("\\")) return fragment;
  let out = "";
  let i = 0;
  while (i < fragment.length) {
    if (fragment[i] === "\\" && /[a-zA-Z]/i.test(fragment[i + 1] ?? "")) {
      const end = consumeBareLatexRun(fragment, i);
      if (end > i) {
        const piece = fragment.slice(i, end).trimEnd();
        if (piece.length > 0 && /\\/.test(piece)) {
          out += `$${piece}$`;
          i = end;
          continue;
        }
      }
    }
    out += fragment[i]!;
    i++;
  }
  return out;
}

function transformOutsideExistingMath(
  s: string,
  fn: (frag: string) => string,
): string {
  if (!s.includes("$")) return fn(s);
  const chunks = s.split("$");
  return chunks
    .map((chunk, idx) => (idx % 2 === 0 ? fn(chunk) : chunk))
    .join("$");
}

function segmentHasBareLatex(s: string): boolean {
  if (!s.trim()) return false;
  return (
    /\^[0-9]|_[0-9a-z]|\)\\^|[²³⁴]/.test(s) ||
    /\\(?:[a-zA-Z]+\*?)/i.test(s)
  );
}

function augmentPlainConstructs(input: string): string {
  let t = input;
  t = t.replace(/\([^()]*\)\^[0-9]+/g, (m) => `$${m}$`);
  t = t.replace(
    /\b([a-zA-Z])\s*=\s*([a-zA-Z0-9+*/().\s-]+)/g,
    (full, v: string, rhs: string) => {
      const r = String(rhs).trim();
      if (!/[\^_]|\\|\\frac|\\sqrt/.test(r)) return full;
      return `$${v}=${r}$`;
    },
  );
  t = t.replace(/\b[a-zA-Z][a-zA-Z0-9']*\^[0-9]+\b/g, (m) => {
    if (m.includes("$")) return m;
    return `$${m}$`;
  });
  t = t.replace(/\b[a-zA-Z][a-zA-Z0-9']*_[0-9a-z]+\b/gi, (m) => {
    if (m.includes("$")) return m;
    return `$${m}$`;
  });
  t = t.replace(/([a-zA-Z])[²³⁴]/g, (fullMatch, letter: string) => {
    const sup = fullMatch.slice(-1);
    const map: Record<string, string> = { "²": "^2", "³": "^3", "⁴": "^4" };
    return `$${letter}${map[sup] ?? "^2"}$`;
  });
  t = t.replace(/\([^()]+\)[²³⁴]/g, (full) => {
    const sup = full.slice(-1);
    const map: Record<string, string> = { "²": "^2", "³": "^3", "⁴": "^4" };
    const base = full.slice(0, -1);
    return `$${base}${map[sup] ?? "^2"}$`;
  });
  return t;
}

export function augmentMathDelimiters(input: string): string {
  const s = input ?? "";
  if (!s.trim()) return s;

  const hasDelimiter = /\$|\\\(|\\\[/.test(s);
  if (hasDelimiter) return s;

  if (!segmentHasBareLatex(s)) return s;

  let t = transformOutsideExistingMath(s, augmentPlainConstructs);
  t = transformOutsideExistingMath(t, wrapNestedConstructs);
  t = transformOutsideExistingMath(t, wrapBackslashSequencesOutsideDelimiters);
  return t;
}
