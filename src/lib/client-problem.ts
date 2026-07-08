import type { GeneratedProblem, GeneratedProblemSet } from "./types";

/** 모바일·웹 클라이언트에 불필요한 시각화·마이그레이션 필드 */
const CLIENT_OMIT = new Set([
  "visualizationData",
  "solutionVisualizationData",
  "visualizationMigrationStatus",
  "visualizationMigrationError",
  "jsxGraph",
  "chart",
]);

export function stripProblemForClient<T extends GeneratedProblem>(problem: T): T {
  const next = { ...problem } as Record<string, unknown>;
  for (const key of CLIENT_OMIT) {
    delete next[key];
  }
  return next as T;
}

export function stripProblemSetForClient(
  problemSet: GeneratedProblemSet,
): GeneratedProblemSet {
  return {
    ...problemSet,
    problems: problemSet.problems.map(stripProblemForClient),
  };
}
