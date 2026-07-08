import type { GeneratedProblem, ProblemBankItem } from "./types";

/**
 * 그래프·도표·도형 생성/bake 전역 스위치.
 * 기본 꺼짐. 다시 켜려면 `.env.local`에 `VISUALIZATION_ENABLED=true`
 */
export function isVisualizationEnabled(): boolean {
  return process.env.VISUALIZATION_ENABLED?.trim() === "true";
}

export function clearProblemVisualization<T extends GeneratedProblem | ProblemBankItem>(
  problem: T,
): T {
  if (isVisualizationEnabled()) return problem;
  return {
    ...problem,
    chart: null,
    jsxGraph: null,
    visualizationData: null,
    solutionVisualizationData: null,
    visualizationMigrationStatus: "completed",
    visualizationMigrationError: null,
  };
}

export function clearBankItemVisualization(item: ProblemBankItem): ProblemBankItem {
  return clearProblemVisualization(item);
}

export const VISUALIZATION_DISABLED_PROMPT_RULES = `- chart: 항상 null (도표 생성 사용 안 함)
- jsxGraph: 항상 null (도형 다이어그램 생성 사용 안 함)
- visualizationData / solutionVisualizationData: 항상 null (그래프·도형 이미지 생성 사용 안 함)
- 위 시각화 필드를 문제 JSON에 넣지 말 것`;
