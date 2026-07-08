import { completeAzureJsonPrompt } from "./azure";
import { env } from "./env";
import { buildVisualizationAuditUserPrompt } from "./visualization-needed-prompt";
import { clearProblemVisualization, isVisualizationEnabled } from "./visualization-policy";
import type { GeneratedProblem, ProblemBankItem } from "./types";

function parseJsonFromText(text: string) {
  const fenced = text.match(/```(?:json)?\s*([\s\S]*?)```/);
  const jsonText = fenced?.[1] ?? text;
  return JSON.parse(jsonText.trim()) as Record<string, unknown>;
}

type ProblemText = Pick<
  GeneratedProblem,
  "title" | "prompt" | "explanation" | "conceptTags"
>;

export async function isGraphRequiredToSolve(problem: ProblemText): Promise<{
  graphRequiredToSolve: boolean;
  reason: string;
}> {
  if (!isVisualizationEnabled()) {
    return { graphRequiredToSolve: false, reason: "시각화 생성 비활성화" };
  }
  const deployment = env.azureOpenAiDeployment?.trim();
  if (!deployment) {
    return { graphRequiredToSolve: true, reason: "Azure 미설정 — viz 유지" };
  }

  const text = await completeAzureJsonPrompt({
    deploymentName: deployment,
    userPrompt: buildVisualizationAuditUserPrompt({
      title: problem.title,
      prompt: problem.prompt,
      explanation: problem.explanation,
      conceptTags: problem.conceptTags ?? [],
    }),
    temperatureForChat: 0.1,
    maxTokens: 512,
  });

  const raw = parseJsonFromText(text);
  return {
    graphRequiredToSolve: Boolean(
      (raw as { graphRequiredToSolve?: boolean }).graphRequiredToSolve,
    ),
    reason:
      typeof (raw as { reason?: unknown }).reason === "string"
        ? (raw as { reason: string }).reason
        : "이유 없음",
  };
}

function hasViz(problem: {
  visualizationData?: GeneratedProblem["visualizationData"];
  solutionVisualizationData?: GeneratedProblem["solutionVisualizationData"];
}): boolean {
  return Boolean(problem.visualizationData || problem.solutionVisualizationData);
}

/** 풀이에 그래프가 꼭 필요하지 않으면 viz 필드 제거 (생성·bake 직전 게이트) */
export async function stripVisualizationIfNotRequired<
  T extends GeneratedProblem | ProblemBankItem,
>(problem: T): Promise<T> {
  if (!isVisualizationEnabled()) return clearProblemVisualization(problem) as T;
  if (!hasViz(problem)) return problem;

  const { graphRequiredToSolve, reason } = await isGraphRequiredToSolve(problem);
  if (graphRequiredToSolve) return problem;

  return {
    ...problem,
    visualizationData: null,
    solutionVisualizationData: null,
    visualizationMigrationStatus: "completed",
    visualizationMigrationError: null,
  };
}

export async function stripVisualizationsIfNotRequired(
  problems: GeneratedProblem[],
): Promise<GeneratedProblem[]> {
  const next: GeneratedProblem[] = [];
  for (const problem of problems) {
    next.push(await stripVisualizationIfNotRequired(problem));
  }
  return next;
}
