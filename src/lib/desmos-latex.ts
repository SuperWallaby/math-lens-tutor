/** Desmos API expects LaTeX (`\sin\left(x\right)`), not plain `sin(x)`. */

const TRIG_FNS = [
  "sin",
  "cos",
  "tan",
  "sec",
  "csc",
  "cot",
  "log",
  "ln",
  "sqrt",
] as const;

/** Static PNG bake: unresolved single-letter params → numeric defaults. */
const STATIC_PARAM_DEFAULTS: Record<string, number> = {
  a: 1,
  b: 0,
  c: 0,
  d: 0,
  e: 0,
  k: 1,
  m: 1,
  n: 1,
  p: 1,
  r: 1,
  t: 1,
};

const RESERVED_IDENTIFIERS = new Set(["x", "y", "e", "pi"]);

function normalizeLogSubscripts(latex: string): string {
  return latex.replace(
    /\blog_([0-9]+)\s*\(/gi,
    (_, base: string) => `\\log_{${base}}\\left(`,
  );
}

function normalizeAbsoluteValueBars(latex: string): string {
  if (!latex.includes("|") || latex.includes("\\left|")) return latex;
  return latex.replace(/\|([^|]+)\|/g, "\\left|$1\\right|");
}

function convertFunctionNotationToY(latex: string): string {
  return latex.replace(
    /^([fgh]|f_[0-9]+|g_[0-9]+)\s*\(\s*x\s*\)\s*=/i,
    "y=",
  );
}

function normalizeFocusPointLabel(latex: string): string {
  const match = latex.match(/^F_\d+\s*=\s*(\([^)]+\))\s*$/i);
  return match ? match[1]! : latex;
}

function substituteStaticParameters(latex: string): string {
  return latex.replace(/\b([a-z])\b/gi, (token, letter: string) => {
    const key = letter.toLowerCase();
    if (RESERVED_IDENTIFIERS.has(key)) return token;
    if (!(key in STATIC_PARAM_DEFAULTS)) return token;
    return String(STATIC_PARAM_DEFAULTS[key]);
  });
}

export function isPlottableDesmosExpression(line: string): boolean {
  const s = line.trim();
  if (!s) return false;
  if (/\\lim[_\s{]/i.test(s) || /^lim[_\s(]/i.test(s)) return false;
  if (/\\to\b/i.test(s) && /lim/i.test(s)) return false;
  if (/^F_\d+\s*=/i.test(s)) return false;
  if (/^[A-Z]_\d+\s*=/.test(s)) return false;
  if (/^\d+\s*=\s*[-\d.]+\s*$/.test(s)) return false;
  return /=/.test(s) || /^\([^)]+\)$/.test(s);
}

export function normalizeDesmosLatex(latex: string): string {
  let s = latex.trim();
  if (!s) return s;

  s = normalizeFocusPointLabel(s);
  s = convertFunctionNotationToY(s);
  s = normalizeLogSubscripts(s);
  s = normalizeAbsoluteValueBars(s);

  for (const fn of TRIG_FNS) {
    s = s.replace(
      new RegExp(`\\b${fn}\\(([^()]*)\\)`, "g"),
      `\\${fn}\\left($1\\right)`,
    );
  }

  return s;
}

/** Bake/capture용 — Desmos가 실제로 그릴 수 있는 형태로 정리 */
export function sanitizeDesmosExpression(latex: string): string {
  let s = normalizeDesmosLatex(latex);
  s = substituteStaticParameters(s);
  return s.replace(/^y=\s+/, "y=");
}

function maybeSplitLogSumExpression(expression: string): {
  expression: string;
  expressions?: string[];
} {
  if (!/^y=/i.test(expression) || !/\\log|log_/i.test(expression)) {
    return { expression };
  }
  const body = expression.replace(/^y=/i, "").trim();
  const parts = body
    .split("+")
    .map((part) => part.trim())
    .filter(Boolean);
  if (parts.length < 2 || !parts.every((part) => /\\log|log_/i.test(part))) {
    return { expression };
  }
  return {
    expression: `y=${parts[0]}`,
    expressions: parts.slice(1).map((part) => `y=${part}`),
  };
}

function flattenGraphLines(...rawLines: string[]): string[] {
  const out: string[] = [];
  const seen = new Set<string>();

  for (const raw of rawLines) {
    const split = maybeSplitLogSumExpression(sanitizeDesmosExpression(raw));
    for (const line of [split.expression, ...(split.expressions ?? [])]) {
      if (!line || seen.has(line) || !isPlottableDesmosExpression(line)) continue;
      seen.add(line);
      out.push(line);
    }
  }

  return out;
}

export function sanitizeDesmosExpressionList(
  expressions: string[] | undefined,
  primary: string,
): string[] | undefined {
  const lines = flattenGraphLines(primary, ...(expressions ?? []));
  if (lines.length <= 1) return undefined;
  const [, ...rest] = lines;
  return rest.length > 0 ? rest : undefined;
}

export function sanitizeFunctionGraphData<
  T extends {
    expression: string;
    expressions?: string[];
  },
>(data: T): T {
  const lines = flattenGraphLines(data.expression, ...(data.expressions ?? []));
  if (lines.length === 0) {
    return { ...data, expression: sanitizeDesmosExpression(data.expression) };
  }
  const [expression, ...expressions] = lines;
  return {
    ...data,
    expression,
    expressions: expressions.length > 0 ? expressions : undefined,
  };
}
