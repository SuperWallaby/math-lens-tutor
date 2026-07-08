import type { GeneratedProblem } from "./types";
import { normalizeProblemVisualization } from "./visualization-schema";
import { clearProblemVisualization } from "./visualization-policy";
import { stripMathDelimiters } from "./answer-normalize";
import { normalizeMultipleChoiceProblem } from "./choice-label-format";

export { stripMathDelimiters };

const EXPRESSION_ANSWER =
  /[×x×^=]|\\times|\\cdot|\$\([^)]+\)\$|\([^)]{3,}\)|\\begin\{|\\frac|→/i;
const LONG_TEXT_ANSWER = /.{25,}/;

/** 모바일 한 줄 입력으로 받기 어려운 free_response */
export function needsShortAnswerRepair(problem: {
  type: string;
  prompt: string;
  correctAnswer: string;
  answerFormat?: string | null;
}): boolean {
  if (problem.type !== "free_response") return false;
  if (problem.answerFormat === "long_solution") return true;

  const answer = stripMathDelimiters(problem.correctAnswer);
  const prompt = problem.prompt;

  // 이미 짧은 숫자/분수/라벨 답이면 OK
  if (/^-?\d+(?:\.\d+)?$/.test(answer)) return false;
  if (/^-?\d+\s*\/\s*\d+$/.test(answer)) return false;
  if (/^(나반|가반|같다|가능|불가)$/.test(answer)) return false;

  if (LONG_TEXT_ANSWER.test(problem.correctAnswer)) return true;
  if (/소인수분해|인수분해|완전제곱|전개|식을\s*쓰|식으로|하시오\.?\s*$/.test(prompt)) {
    return true;
  }
  if (/풀이\s*과정|설명하시오|서술|간단히\s*설명/.test(prompt)) return true;
  if (EXPRESSION_ANSWER.test(problem.correctAnswer)) return true;
  if (/[,，].{8,}/.test(answer)) return true;
  if (/^(나반|가반).{4,}/.test(answer)) return true;
  if (/\d+\s*[×^*\\times]\s*\d+/.test(problem.correctAnswer)) return true;

  return false;
}

function extractPromptNumber(prompt: string): number | null {
  const m = prompt.match(/\$?\s*(\d{1,6})\s*\$?/);
  return m ? Number(m[1]) : null;
}

function maxPrimeFactorFromExpression(raw: string): number | null {
  const text = stripMathDelimiters(raw)
    .replace(/\\times/g, "×")
    .replace(/\*/g, "×")
    .replace(/\s+/g, "");
  const primes: number[] = [];

  const caretParts = text.split(/[×*]/);
  for (const part of caretParts) {
    const caret = part.match(/^(\d+)\^(\d+)$/);
    if (caret) {
      primes.push(Number(caret[1]));
      continue;
    }
    const plain = part.match(/^(\d+)$/);
    if (plain) primes.push(Number(plain[1]));
  }

  if (primes.length === 0) return null;
  return Math.max(...primes);
}

function extractAssignedValue(raw: string): string | null {
  const text = stripMathDelimiters(raw);
  const m = text.match(/(?:^|[,;\s])([a-z])\s*=\s*(-?\d+(?:\.\d+)?)/i);
  if (m) return m[2];
  const bare = text.match(/^(-?\d+(?:\.\d+)?)$/);
  if (bare) return bare[1];
  return null;
}

function repairPrimeFactorization(
  problem: GeneratedProblem,
): GeneratedProblem | null {
  if (!/소인수분해/.test(problem.prompt)) return null;

  const n = extractPromptNumber(problem.prompt);
  const maxPrime = maxPrimeFactorFromExpression(problem.correctAnswer);
  if (n == null || maxPrime == null) return null;

  return {
    ...problem,
    type: "free_response",
    title: problem.title.includes("소인수") ? problem.title : "소인수분해",
    prompt: `$${n}$를 소인수분해할 때 가장 큰 소인수는?`,
    correctAnswer: String(maxPrime),
    answerFormat: "short_numeric",
    choices: undefined,
  };
}

function repairNumericAssignment(problem: GeneratedProblem): GeneratedProblem | null {
  const value = extractAssignedValue(problem.correctAnswer);
  if (value == null) return null;

  return {
    ...problem,
    type: "free_response",
    correctAnswer: value,
    answerFormat: "short_numeric",
    choices: undefined,
  };
}

function repairShortLabelAnswer(problem: GeneratedProblem): GeneratedProblem | null {
  const answer = stripMathDelimiters(problem.correctAnswer);
  const label = answer.match(/^(나반|가반|같다|가능|불가)/)?.[1];
  if (!label) return null;

  const shortPrompt = /어느\s*반|가반|나반/.test(problem.prompt)
    ? problem.prompt.split("\n")[0] + "\n\n어느 반의 분산이 더 큰가?"
    : problem.prompt;

  return {
    ...problem,
    type: "free_response",
    prompt: shortPrompt,
    correctAnswer: label,
    answerFormat: "short_answer",
    choices: undefined,
  };
}

function uniqueStrings(items: string[]): string[] {
  const seen = new Set<string>();
  const out: string[] = [];
  for (const item of items) {
    const key = item.trim();
    if (!key || seen.has(key)) continue;
    seen.add(key);
    out.push(key);
  }
  return out;
}

function repairAsMultipleChoice(problem: GeneratedProblem): GeneratedProblem | null {
  const correct = stripMathDelimiters(problem.correctAnswer);
  if (!correct) return null;

  const pool = uniqueStrings([
    correct,
    correct.replace(/-/g, "+"),
    correct.replace(/\+/g, "-"),
    correct.replace(/(\d+)/g, (_, d) => String(Number(d) + 1)),
    correct.replace(/(\d+)/g, (_, d) => String(Math.max(1, Number(d) - 1))),
    `${correct}+1`,
    `${correct}-1`,
  ]).filter((s) => s !== correct);

  const labels = uniqueStrings([correct, ...pool]).slice(0, 5);
  while (labels.length < 5) {
    labels.push(`${correct}?${labels.length}`);
  }

  const choices = labels.slice(0, 5).map((label, i) => ({
    id: String(i + 1),
    label,
  }));

  return {
    ...problem,
    type: "multiple_choice",
    answerFormat: undefined,
    choices,
    correctAnswer: correct,
  };
}

/**
 * 식·서술형 free_response → 짧은 답 또는 객관식으로 변환.
 * 변환 불가 시 null (비활성화 대상).
 */
export function repairProblemForShortInput(
  problem: GeneratedProblem,
): GeneratedProblem | null {
  if (problem.type === "multiple_choice") return problem;
  if (!needsShortAnswerRepair(problem)) {
    const answer = stripMathDelimiters(problem.correctAnswer);
    if (/^-?\d+(?:\.\d+)?$/.test(answer)) {
      return { ...problem, answerFormat: "short_numeric" };
    }
    if (answer.length <= 20) {
      return { ...problem, answerFormat: "short_answer" };
    }
    return problem;
  }

  return (
    repairPrimeFactorization(problem) ??
    repairNumericAssignment(problem) ??
    repairShortLabelAnswer(problem) ??
    repairAsMultipleChoice(problem)
  );
}

export function sanitizeGeneratedProblem(problem: GeneratedProblem): GeneratedProblem {
  let result: GeneratedProblem;
  if (problem.type === "multiple_choice") {
    const { answerFormat: _drop, ...rest } = problem;
    result = normalizeMultipleChoiceProblem(rest).problem;
  } else {
    const repaired = repairProblemForShortInput(problem);
    if (repaired) {
      result = repaired;
    } else {
      const mc = repairAsMultipleChoice(problem);
      result = mc ?? problem;
    }
  }
  return normalizeProblemVisualization(clearProblemVisualization(result));
}
