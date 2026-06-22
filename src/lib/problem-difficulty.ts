import {
  CURRICULUM_TABLE_OF_CONTENTS,
  findCurriculumUnit,
  GRADE_BAND_LABELS,
  type GradeBand,
} from "./curriculum";
import type { GeneratedProblem } from "./types";

export type Difficulty = GeneratedProblem["difficulty"];

const VALID: Difficulty[] = ["easy", "medium", "hard"];

export function parseDifficulty(raw: unknown): Difficulty | null {
  if (typeof raw !== "string") return null;
  const d = raw.trim().toLowerCase();
  return VALID.includes(d as Difficulty) ? (d as Difficulty) : null;
}

const DIFFICULTY_RANK: Record<Difficulty, number> = {
  easy: 0,
  medium: 1,
  hard: 2,
};

export function difficultyRank(raw: unknown): number {
  return DIFFICULTY_RANK[parseDifficulty(raw) ?? "medium"];
}

/** 한 단계 상향 (easy→medium, medium/hard→hard) */
export function bumpDifficulty(raw: unknown): Difficulty {
  const d = parseDifficulty(raw) ?? "medium";
  if (d === "easy") return "medium";
  return "hard";
}

export function meetsMinDifficulty(
  raw: unknown,
  minDifficulty: Difficulty,
): boolean {
  return difficultyRank(raw) >= DIFFICULTY_RANK[minDifficulty];
}

/** AI 프롬프트용 — 해당 학년·단원 기준 상대 난이도 */
export function difficultyRubricForPrompt(params: {
  gradeBand: GradeBand;
  unitName?: string;
  unitSubtitle?: string;
  problemCount?: number;
}): string {
  const band = GRADE_BAND_LABELS[params.gradeBand];
  const unitLine = params.unitName
    ? `Unit: "${params.unitName}" (${params.unitSubtitle ?? ""}).`
    : "";
  const n = params.problemCount ?? 5;

  return `Difficulty (REQUIRED on every problem — relative to ${band} curriculum, NOT absolute):
${unitLine}
- easy: intro / textbook baseline for THIS unit at ${band}; 1 step, no trick distractors.
- medium: typical school exam for THIS unit at ${band}; 2 steps or one common mistake pattern.
- hard: stretch item still fair at ${band}; multi-step but only skills from this unit/grade. No higher-grade tricks.
- Do NOT mark everything "easy". For ${n} problems use roughly: 2 easy, 2 medium, 1 hard (scale if count differs).
- Each problem's difficulty must match its steps for a ${band} student in this unit.`;
}

function unitPhase(unitId?: string): number {
  if (!unitId) return 0.5;
  const located = findCurriculumUnit(unitId);
  if (!located) return 0.5;
  const units = CURRICULUM_TABLE_OF_CONTENTS[located.gradeBand];
  const idx = units.findIndex((u) => u.id === unitId);
  if (idx < 0 || units.length <= 1) return 0.5;
  return idx / (units.length - 1);
}

function targetDistribution(count: number, phase: number): Difficulty[] {
  if (count <= 0) return [];

  const weights: Record<Difficulty, number> =
    phase < 0.33
      ? { easy: 0.5, medium: 0.35, hard: 0.15 }
      : phase > 0.66
        ? { easy: 0.25, medium: 0.45, hard: 0.3 }
        : { easy: 0.35, medium: 0.4, hard: 0.25 };

  const order: Difficulty[] = ["easy", "medium", "hard"];
  const quotas = order.map((d) => Math.floor(count * weights[d]));
  let assigned = quotas.reduce((a, b) => a + b, 0);
  let i = 0;
  while (assigned < count) {
    quotas[i % 3] += 1;
    assigned += 1;
    i += 1;
  }

  const mixed: Difficulty[] = [];
  for (const d of order) {
    const n = quotas[order.indexOf(d)] ?? 0;
    for (let k = 0; k < n; k += 1) mixed.push(d);
  }

  // spread: easy → medium → hard interleave
  const easy = mixed.filter((d) => d === "easy");
  const medium = mixed.filter((d) => d === "medium");
  const hard = mixed.filter((d) => d === "hard");
  const spread: Difficulty[] = [];
  const maxLen = Math.max(easy.length, medium.length, hard.length);
  for (let j = 0; j < maxLen; j += 1) {
    if (j < easy.length) spread.push(easy[j]!);
    if (j < medium.length) spread.push(medium[j]!);
    if (j < hard.length) spread.push(hard[j]!);
  }
  return spread.slice(0, count);
}

function inferFromProblemShape(problem: GeneratedProblem): Difficulty {
  const prompt = `${problem.prompt} ${problem.title}`;
  let score = 0;
  if (problem.type === "multiple_choice") score += 1;
  if (problem.chart != null) score += 1;
  if (problem.jsxGraph != null) score += 2;
  if (/두\s*번|경우|나누|비교|증명|최대|최소|활용/.test(prompt)) score += 1;
  if (/□|빈칸/.test(prompt)) score -= 1;
  if (score <= 0) return "easy";
  if (score <= 2) return "medium";
  return "hard";
}

function needsRecalibration(problems: GeneratedProblem[]): boolean {
  if (problems.length === 0) return false;
  const parsed = problems.map((p) => parseDifficulty(p.difficulty));
  if (parsed.some((d) => d == null)) return true;
  return new Set(parsed).size === 1;
}

/**
 * 학년·단원 맥락으로 난이도 보정.
 * AI가 전부 easy이거나 누락했을 때 분포 재배치; 이미 섞여 있으면 유효값만 정규화.
 */
export function calibrateProblemDifficulties(
  problems: GeneratedProblem[],
  ctx: { gradeBand: GradeBand; unitId?: string },
): GeneratedProblem[] {
  if (problems.length === 0) return problems;

  const phase = unitPhase(ctx.unitId);
  const targets = targetDistribution(problems.length, phase);

  if (!needsRecalibration(problems)) {
    return problems.map((p) => ({
      ...p,
      difficulty: parseDifficulty(p.difficulty) ?? inferFromProblemShape(p),
    }));
  }

  return problems.map((problem, index) => ({
    ...problem,
    difficulty: targets[index] ?? inferFromProblemShape(problem),
  }));
}
