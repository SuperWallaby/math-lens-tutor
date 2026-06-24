type MathRegion = { start: number; end: number };

/** `$…$`, `$$…$$`, `\(…\)`, `\[…\]` 구간 — 잘라낼 때 중간에서 끊지 않음 */
function findMathRegions(source: string): MathRegion[] {
  const regions: MathRegion[] = [];
  let pos = 0;

  while (pos < source.length) {
    const dd = source.indexOf("$$", pos);
    const sd = source.indexOf("$", pos);
    const br = source.indexOf(String.raw`\[`, pos);
    const pa = source.indexOf(String.raw`\(`, pos);

    const candidates: { start: number; kind: "dd" | "sd" | "br" | "pa" }[] = [];
    if (dd >= 0) candidates.push({ start: dd, kind: "dd" });
    if (sd >= 0 && (sd + 1 >= source.length || source[sd + 1] !== "$")) {
      candidates.push({ start: sd, kind: "sd" });
    }
    if (br >= 0) candidates.push({ start: br, kind: "br" });
    if (pa >= 0) candidates.push({ start: pa, kind: "pa" });

    if (candidates.length === 0) break;

    const next = candidates.reduce((a, b) => (a.start <= b.start ? a : b));
    pos = next.start;

    if (next.kind === "dd") {
      const close = source.indexOf("$$", pos + 2);
      if (close < 0) break;
      regions.push({ start: pos, end: close + 2 });
      pos = close + 2;
      continue;
    }

    if (next.kind === "sd") {
      const close = findClosingSingleDollar(source, pos + 1);
      if (close < 0) break;
      regions.push({ start: pos, end: close + 1 });
      pos = close + 1;
      continue;
    }

    if (next.kind === "br") {
      const close = source.indexOf(String.raw`\]`, pos + 2);
      if (close < 0) break;
      regions.push({ start: pos, end: close + 2 });
      pos = close + 2;
      continue;
    }

    const close = source.indexOf(String.raw`\)`, pos + 2);
    if (close < 0) break;
    regions.push({ start: pos, end: close + 2 });
    pos = close + 2;
  }

  return regions;
}

function findClosingSingleDollar(source: string, from: number): number {
  let i = source.indexOf("$", from);
  while (i >= 0) {
    if (i + 1 >= source.length || source[i + 1] !== "$") return i;
    i = source.indexOf("$", i + 2);
  }
  return -1;
}

function regionContaining(regions: MathRegion[], index: number): MathRegion | null {
  for (const region of regions) {
    if (index > region.start && index < region.end) return region;
  }
  return null;
}

/**
 * 미리보기용 말줄임 — 수식 구간은 통째로 유지하거나, 너무 길면 구간 앞에서 자름.
 * (클라이언트 MixedMathText/KaTeX가 깨지지 않게)
 */
export function truncateMathSafe(
  text: string,
  max: number,
  options?: { preserveBreaks?: boolean; mathOverflow?: number },
): string {
  const preserveBreaks = options?.preserveBreaks ?? false;
  const mathOverflow = options?.mathOverflow ?? 48;
  const normalized = preserveBreaks
    ? text.trim()
    : text.replace(/\s+/g, " ").trim();

  if (normalized.length <= max) return normalized;

  const ellipsis = "…";
  const budget = Math.max(1, max - ellipsis.length);
  let cut = budget;

  const regions = findMathRegions(normalized);
  const inside = regionContaining(regions, cut);
  if (inside) {
    if (inside.end <= budget + mathOverflow) {
      cut = inside.end;
    } else {
      cut = inside.start;
    }
  }

  if (cut < 1) cut = budget;

  const prefix = normalized.slice(0, cut);
  const lastNl = prefix.lastIndexOf("\n");
  const lastSp = prefix.lastIndexOf(" ");
  const lastBreak = Math.max(lastNl, lastSp);
  if (lastBreak > cut * 0.55) {
    const candidate = lastBreak;
    if (!regionContaining(regions, candidate)) {
      cut = candidate;
    }
  }

  return `${normalized.slice(0, cut).trimEnd()}${ellipsis}`;
}

/** 목록 미리보기 — 수식 구간을 공백으로 치환 (한글 뼈대만) */
export function stripMathForListPreview(text: string): string {
  return text
    .replace(/\$\$[\s\S]*?\$\$/g, " ")
    .replace(/\$[^$\n]+\$/g, " ")
    .replace(/\\\[[\s\S]*?\\\]/g, " ")
    .replace(/\\\([\s\S]*?\\\)/g, " ")
    .replace(/\s+/g, " ")
    .trim();
}

function textHasMathDelimiters(text: string): boolean {
  return /\$\$?|\\\(|\\\[/.test(text);
}

/**
 * 목록 제목 — 수식이 많은 문제는 한글 요약 우선, 아니면 수식 구간을 통째로 유지하며 자름.
 */
export function formatListTitleWithMath(
  text: string,
  max: number,
  fallbackLabel?: string,
): string {
  const trimmed = text.trim();
  if (!trimmed) return fallbackLabel?.trim() || "풀이 분석";
  if (trimmed.length <= max) return trimmed;

  if (textHasMathDelimiters(trimmed)) {
    const plain = stripMathForListPreview(trimmed);
    if (plain.length >= 8) {
      return truncateMathSafe(plain, max, { preserveBreaks: false });
    }
    const safe = truncateMathSafe(trimmed, max, {
      preserveBreaks: false,
      mathOverflow: 0,
    });
    if (!textHasMathDelimiters(safe.replace(/…$/, ""))) {
      return safe;
    }
    return fallbackLabel?.trim() || "수식 문제";
  }

  return truncateMathSafe(trimmed, max, { preserveBreaks: false });
}
