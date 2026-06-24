import { completeAzureJsonPrompt } from "./azure";
import { env } from "./env";
import type { GeneratedProblem, ProblemBankItem } from "./types";
import {
  parseVisualizationData,
  validateVisualizationData,
  normalizeProblemVisualization,
  type VisualizationData,
  type VisualizationMigrationStatus,
} from "./visualization-schema";

function parseJsonFromText(text: string) {
  const fenced = text.match(/```(?:json)?\s*([\s\S]*?)```/);
  const jsonText = fenced?.[1] ?? text;
  return JSON.parse(jsonText.trim()) as Record<string, unknown>;
}

export type VisualizationBundle = {
  visualizationData: VisualizationData;
  solutionVisualizationData: VisualizationData;
  migrationStatus: VisualizationMigrationStatus;
  migrationError?: string | null;
};

const VISUALIZATION_PROMPT = `You analyze Korean math problems and decide if a graph or geometry diagram helps solve or explain them.

Return JSON only:
{
  "needed": boolean,
  "visualizationData": null | {
    "type": "function_graph" | "geometry" | "coordinate",
    "engine": "desmos" | "jsxgraph",
    "data": {}
  },
  "solutionVisualizationData": null | { same shape as visualizationData },
  "reason": "short Korean explanation"
}

Rules:
- function_graph + engine desmos: y= expression, optional xRange/yRange [-5,5] style tuples
- geometry + engine jsxgraph: shape triangle|rectangle|circle|polygon|custom, points { "A": [x,y], ... }, showLabels
- coordinate + engine jsxgraph: board.boundingbox + elements array for JSXGraph
- If no diagram needed, needed=false and both visualization fields null
- Solution diagram only when explanation benefits from a separate figure (e.g. completed graph, auxiliary lines)
- Do NOT duplicate prompt diagram in solution unless it adds new information
- Prefer null over weak or decorative visuals`;

function hasAzure(): boolean {
  return Boolean(env.azureOpenAiEndpoint?.trim() && env.azureOpenAiDeployment?.trim());
}

export async function generateVisualizationBundle(params: {
  title: string;
  prompt: string;
  explanation: string;
  conceptTags: string[];
  existingChart?: GeneratedProblem["chart"];
  existingJsxGraph?: GeneratedProblem["jsxGraph"];
}): Promise<VisualizationBundle> {
  if (params.existingJsxGraph?.diagramNeeded) {
    return {
      visualizationData: {
        type: "geometry",
        engine: "jsxgraph",
        data: { legacyJsxGraph: params.existingJsxGraph },
      },
      solutionVisualizationData: null,
      migrationStatus: "completed",
    };
  }

  if (params.existingChart) {
    return {
      visualizationData: {
        type: "chart",
        engine: "chartjs",
        data: {
          type: params.existingChart.type,
          data: params.existingChart.data,
          options: params.existingChart.options,
        },
      },
      solutionVisualizationData: null,
      migrationStatus: "completed",
    };
  }

  if (!hasAzure()) {
    return {
      visualizationData: null,
      solutionVisualizationData: null,
      migrationStatus: "failed",
      migrationError: "Azure OpenAI not configured",
    };
  }

  try {
    const userPrompt = `${VISUALIZATION_PROMPT}

Problem title: ${params.title}
Prompt: ${params.prompt}
Explanation: ${params.explanation}
Concept tags: ${params.conceptTags.join(", ")}`;

    const deployment = env.azureOpenAiDeployment!.trim();
    const text = await completeAzureJsonPrompt({
      deploymentName: deployment,
      userPrompt,
      temperatureForChat: 0.2,
      maxTokens: 2048,
    });
    const raw = parseJsonFromText(text);

    const needed = Boolean((raw as { needed?: boolean }).needed);
    if (!needed) {
      return {
        visualizationData: null,
        solutionVisualizationData: null,
        migrationStatus: "completed",
      };
    }

    const visualizationData = validateVisualizationData(
      parseVisualizationData((raw as { visualizationData?: unknown }).visualizationData),
    );
    const solutionVisualizationData = validateVisualizationData(
      parseVisualizationData(
        (raw as { solutionVisualizationData?: unknown }).solutionVisualizationData,
      ),
    );

    return {
      visualizationData,
      solutionVisualizationData,
      migrationStatus: "completed",
    };
  } catch (error) {
    return {
      visualizationData: null,
      solutionVisualizationData: null,
      migrationStatus: "failed",
      migrationError:
        error instanceof Error ? error.message : "visualization generation failed",
    };
  }
}

export async function enrichGeneratedProblemWithVisualization(
  problem: GeneratedProblem,
): Promise<GeneratedProblem> {
  const normalized = normalizeProblemVisualization(problem);
  if (normalized.visualizationData != null) {
    return {
      ...normalized,
      visualizationMigrationStatus: "completed",
      visualizationMigrationError: null,
    };
  }

  const bundle = await generateVisualizationBundle({
    title: problem.title,
    prompt: problem.prompt,
    explanation: problem.explanation,
    conceptTags: problem.conceptTags,
    existingChart: problem.chart,
    existingJsxGraph: problem.jsxGraph,
  });

  return {
    ...normalized,
    visualizationData: bundle.visualizationData,
    solutionVisualizationData: bundle.solutionVisualizationData,
    visualizationMigrationStatus: bundle.migrationStatus,
    visualizationMigrationError: bundle.migrationError ?? null,
  };
}

export async function migrateBankItemVisualization(
  item: ProblemBankItem,
): Promise<ProblemBankItem> {
  if (
    item.visualizationMigrationStatus === "completed" &&
    (item.visualizationData != null ||
      (!item.chart && !item.jsxGraph?.diagramNeeded))
  ) {
    return item;
  }

  const bundle = await generateVisualizationBundle({
    title: item.title,
    prompt: item.prompt,
    explanation: item.explanation,
    conceptTags: item.conceptTags,
    existingChart: item.chart,
    existingJsxGraph: item.jsxGraph,
  });

  return {
    ...item,
    visualizationData: bundle.visualizationData,
    solutionVisualizationData: bundle.solutionVisualizationData,
    visualizationMigrationStatus: bundle.migrationStatus,
    visualizationMigrationError: bundle.migrationError ?? null,
  };
}

function problemNeedsVisualizationMigration(problem: GeneratedProblem): boolean {
  if (
    problem.visualizationMigrationStatus === "completed" &&
    (problem.visualizationData != null ||
      (!problem.chart && !problem.jsxGraph?.diagramNeeded))
  ) {
    return false;
  }
  return true;
}

/** generated_problem_sets 내 문제 일괄 visualizationData 보강 */
export async function migrateGeneratedProblemSet(
  problemSet: { id: string; problems: GeneratedProblem[] },
): Promise<GeneratedProblem[]> {
  const problems: GeneratedProblem[] = [];

  for (const problem of problemSet.problems) {
    if (!problemNeedsVisualizationMigration(problem)) {
      problems.push(normalizeProblemVisualization(problem));
      continue;
    }
    problems.push(await enrichGeneratedProblemWithVisualization(problem));
  }

  return problems;
}
