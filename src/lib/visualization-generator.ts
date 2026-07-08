import { completeAzureJsonPrompt } from "./azure";
import { env } from "./env";
import type { GeneratedProblem, ProblemBankItem } from "./types";
import {
  bakeVisualizationBundle,
  type VisualizationBakeOptions,
} from "./visualization-bake";
import {
  withVisualizationBaker,
} from "./visualization-baker";
import {
  parseVisualizationData,
  validateVisualizationData,
  normalizeProblemVisualization,
  visualizationNeedsBaking,
  type VisualizationData,
  type VisualizationMigrationStatus,
} from "./visualization-schema";
import {
  buildVisualizationGenerationUserPrompt,
} from "./visualization-needed-prompt";
import { isVisualizationEnabled } from "./visualization-policy";

function hasAzure(): boolean {
  return Boolean(env.azureOpenAiEndpoint?.trim() && env.azureOpenAiDeployment?.trim());
}

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

function isRetryableAzureError(error: unknown): boolean {
  const message = error instanceof Error ? error.message : String(error);
  return /fetch failed|timeout|ECONNRESET|ETIMEDOUT|503|429|502|504/i.test(
    message,
  );
}

async function sleep(ms: number) {
  await new Promise((resolve) => setTimeout(resolve, ms));
}

async function completeVisualizationPrompt(params: {
  deploymentName: string;
  userPrompt: string;
}) {
  const maxAttempts = 3;
  let lastError: unknown;

  for (let attempt = 1; attempt <= maxAttempts; attempt += 1) {
    try {
      return await completeAzureJsonPrompt({
        deploymentName: params.deploymentName,
        userPrompt: params.userPrompt,
        temperatureForChat: 0.2,
        maxTokens: 2048,
      });
    } catch (error) {
      lastError = error;
      if (!isRetryableAzureError(error) || attempt === maxAttempts) {
        throw error;
      }
      await sleep(1500 * attempt);
    }
  }

  throw lastError;
}

function bundleNeedsBaking(bundle: VisualizationBundle): boolean {
  return (
    visualizationNeedsBaking(bundle.visualizationData) ||
    visualizationNeedsBaking(bundle.solutionVisualizationData)
  );
}

async function finalizeVisualizationBundle(
  bundle: VisualizationBundle,
  bakeOptions: VisualizationBakeOptions = {},
): Promise<VisualizationBundle> {
  if (bundle.migrationStatus === "failed") return bundle;

  if (!bundle.visualizationData && !bundle.solutionVisualizationData) {
    return { ...bundle, migrationStatus: "completed", migrationError: null };
  }

  if (bakeOptions.skipBake) {
    return bundle;
  }

  if (!bundleNeedsBaking(bundle) && !bakeOptions.rebake) {
    return { ...bundle, migrationStatus: "completed", migrationError: null };
  }

  try {
    const baked = await bakeVisualizationBundle({
      visualizationData: bundle.visualizationData,
      solutionVisualizationData: bundle.solutionVisualizationData,
      options: bakeOptions,
    });
    return {
      visualizationData: baked.visualizationData,
      solutionVisualizationData: baked.solutionVisualizationData,
      migrationStatus: "completed",
      migrationError: null,
    };
  } catch (error) {
    return {
      visualizationData: null,
      solutionVisualizationData: null,
      migrationStatus: "failed",
      migrationError:
        error instanceof Error ? error.message : "visualization bake failed",
    };
  }
}

export async function generateVisualizationBundle(
  params: {
    title: string;
    prompt: string;
    explanation: string;
    conceptTags: string[];
    existingChart?: GeneratedProblem["chart"];
    existingJsxGraph?: GeneratedProblem["jsxGraph"];
  },
  bakeOptions: VisualizationBakeOptions = {},
): Promise<VisualizationBundle> {
  if (!isVisualizationEnabled()) {
    return {
      visualizationData: null,
      solutionVisualizationData: null,
      migrationStatus: "completed",
      migrationError: null,
    };
  }

  let bundle: VisualizationBundle;

  if (params.existingJsxGraph?.diagramNeeded) {
    bundle = {
      visualizationData: {
        type: "geometry",
        engine: "jsxgraph",
        data: { legacyJsxGraph: params.existingJsxGraph },
      },
      solutionVisualizationData: null,
      migrationStatus: "completed",
    };
  } else if (params.existingChart) {
    bundle = {
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
  } else if (!hasAzure()) {
    return {
      visualizationData: null,
      solutionVisualizationData: null,
      migrationStatus: "failed",
      migrationError: "Azure OpenAI not configured",
    };
  } else {
    try {
      const userPrompt = buildVisualizationGenerationUserPrompt({
        title: params.title,
        prompt: params.prompt,
        explanation: params.explanation,
        conceptTags: params.conceptTags,
      });

      const deployment = env.azureOpenAiDeployment!.trim();
      const text = await completeVisualizationPrompt({
        deploymentName: deployment,
        userPrompt,
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

      bundle = {
        visualizationData: validateVisualizationData(
          parseVisualizationData((raw as { visualizationData?: unknown }).visualizationData),
        ),
        solutionVisualizationData: validateVisualizationData(
          parseVisualizationData(
            (raw as { solutionVisualizationData?: unknown }).solutionVisualizationData,
          ),
        ),
        migrationStatus: "completed",
        migrationError: null,
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

  return finalizeVisualizationBundle(bundle, bakeOptions);
}

function problemHasDiagramSource(problem: GeneratedProblem): boolean {
  return Boolean(
    problem.chart ||
      problem.jsxGraph?.diagramNeeded ||
      problem.visualizationData ||
      problem.solutionVisualizationData,
  );
}

function problemIsFullyMigrated(
  problem: GeneratedProblem,
  bakeOptions: VisualizationBakeOptions = {},
): boolean {
  if (bakeOptions.rebake) return false;
  if (problem.visualizationMigrationStatus !== "completed") return false;
  if (!problemHasDiagramSource(problem)) return true;

  const normalized = normalizeProblemVisualization(problem);
  return (
    !visualizationNeedsBaking(normalized.visualizationData) &&
    !visualizationNeedsBaking(normalized.solutionVisualizationData)
  );
}

function bankItemIsFullyMigrated(
  item: ProblemBankItem,
  bakeOptions: VisualizationBakeOptions = {},
): boolean {
  if (bakeOptions.rebake) return false;
  if (item.visualizationMigrationStatus !== "completed") return false;
  const hasSource = Boolean(
    item.chart || item.jsxGraph?.diagramNeeded || item.visualizationData || item.solutionVisualizationData,
  );
  if (!hasSource) return true;

  const prompt = validateVisualizationData(parseVisualizationData(item.visualizationData));
  const solution = validateVisualizationData(
    parseVisualizationData(item.solutionVisualizationData),
  );
  return !visualizationNeedsBaking(prompt) && !visualizationNeedsBaking(solution);
}

async function bakeExistingProblemVisualization(
  problem: GeneratedProblem,
  bakeOptions: VisualizationBakeOptions = {},
): Promise<GeneratedProblem> {
  const normalized = normalizeProblemVisualization(problem);
  const bundle = await finalizeVisualizationBundle(
    {
      visualizationData: normalized.visualizationData,
      solutionVisualizationData: normalized.solutionVisualizationData,
      migrationStatus: "completed",
      migrationError: null,
    },
    bakeOptions,
  );

  return {
    ...normalized,
    visualizationData: bundle.visualizationData,
    solutionVisualizationData: bundle.solutionVisualizationData,
    visualizationMigrationStatus: bundle.migrationStatus,
    visualizationMigrationError: bundle.migrationError ?? null,
  };
}

export async function enrichGeneratedProblemWithVisualization(
  problem: GeneratedProblem,
  bakeOptions: VisualizationBakeOptions = {},
): Promise<GeneratedProblem> {
  if (problemIsFullyMigrated(problem, bakeOptions)) {
    return normalizeProblemVisualization(problem);
  }

  const normalized = normalizeProblemVisualization(problem);
  if (normalized.visualizationData || normalized.solutionVisualizationData) {
    return bakeExistingProblemVisualization(problem, bakeOptions);
  }

  const bundle = await generateVisualizationBundle(
    {
      title: problem.title,
      prompt: problem.prompt,
      explanation: problem.explanation,
      conceptTags: problem.conceptTags,
      existingChart: problem.chart,
      existingJsxGraph: problem.jsxGraph,
    },
    bakeOptions,
  );

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
  bakeOptions: VisualizationBakeOptions = {},
): Promise<ProblemBankItem> {
  if (bankItemIsFullyMigrated(item, bakeOptions)) {
    return item;
  }

  const promptViz = validateVisualizationData(parseVisualizationData(item.visualizationData));
  const solutionViz = validateVisualizationData(
    parseVisualizationData(item.solutionVisualizationData),
  );

  if (promptViz || solutionViz) {
    const bundle = await finalizeVisualizationBundle(
      {
        visualizationData: promptViz,
        solutionVisualizationData: solutionViz,
        migrationStatus: "completed",
        migrationError: null,
      },
      bakeOptions,
    );
    return {
      ...item,
      visualizationData: bundle.visualizationData,
      solutionVisualizationData: bundle.solutionVisualizationData,
      visualizationMigrationStatus: bundle.migrationStatus,
      visualizationMigrationError: bundle.migrationError ?? null,
    };
  }

  const bundle = await generateVisualizationBundle(
    {
      title: item.title,
      prompt: item.prompt,
      explanation: item.explanation,
      conceptTags: item.conceptTags,
      existingChart: item.chart,
      existingJsxGraph: item.jsxGraph,
    },
    bakeOptions,
  );

  return {
    ...item,
    visualizationData: bundle.visualizationData,
    solutionVisualizationData: bundle.solutionVisualizationData,
    visualizationMigrationStatus: bundle.migrationStatus,
    visualizationMigrationError: bundle.migrationError ?? null,
  };
}

/** generated_problem_sets 내 문제 일괄 visualizationData 보강 */
export async function migrateGeneratedProblemSet(
  problemSet: { id: string; problems: GeneratedProblem[] },
  bakeOptions: VisualizationBakeOptions = {},
): Promise<GeneratedProblem[]> {
  const problems: GeneratedProblem[] = [];

  for (const problem of problemSet.problems) {
    if (problemIsFullyMigrated(problem, bakeOptions)) {
      problems.push(normalizeProblemVisualization(problem));
      continue;
    }
    problems.push(await enrichGeneratedProblemWithVisualization(problem, bakeOptions));
  }

  return problems;
}

export { withVisualizationBaker } from "./visualization-baker";
