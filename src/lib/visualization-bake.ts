import type { StaticAssetFields, VisualizationData } from "./visualization-schema";
import {
  normalizeProblemVisualization,
  validateVisualizationData,
  visualizationNeedsBaking,
} from "./visualization-schema";
import {
  assertBakeableVisualization,
  bakeVisualizationPng,
  localVizPngExists,
  storeVisualizationPng,
  visualizationContentHash,
  withVisualizationBaker,
} from "./visualization-baker";
import type { GeneratedProblem, GeneratedProblemSet } from "./types";
import { clearProblemVisualization, isVisualizationEnabled } from "./visualization-policy";

export type VisualizationBakeOptions = {
  skipBake?: boolean;
  rebake?: boolean;
};

const CAPTURE_DIMENSIONS = {
  function_graph: { width: 800, height: 400 },
  geometry: { width: 800, height: 392 },
  coordinate: { width: 800, height: 392 },
  chart: { width: 800, height: 264 },
} as const;

function dimensionsForType(type: string): { width: number; height: number } {
  return CAPTURE_DIMENSIONS[type as keyof typeof CAPTURE_DIMENSIONS] ?? {
    width: 800,
    height: 400,
  };
}

async function attachStaticAsset(
  viz: Exclude<VisualizationData, null>,
  asset: StaticAssetFields,
): Promise<Exclude<VisualizationData, null>> {
  return {
    type: viz.type,
    engine: "static",
    data: {
      ...(viz.data ?? {}),
      ...asset,
    },
  };
}

export async function bakeVisualizationData(
  raw: VisualizationData,
  options: VisualizationBakeOptions = {},
): Promise<VisualizationData | null> {
  if (!isVisualizationEnabled()) return null;
  const validated = validateVisualizationData(raw);
  if (!validated) return null;

  if (options.skipBake) return validated;

  assertBakeableVisualization(validated);

  const contentHash = visualizationContentHash(validated);
  const existingUrl =
    typeof validated.data.imageUrl === "string" ? validated.data.imageUrl.trim() : "";
  const existingHash =
    typeof validated.data.contentHash === "string" ? validated.data.contentHash.trim() : "";

  if (
    !options.rebake &&
    validated.engine === "static" &&
    existingUrl &&
    existingHash === contentHash &&
    (await localVizPngExists(contentHash))
  ) {
    return validated;
  }

  const { width, height } = dimensionsForType(validated.type);
  const maxAttempts = 3;
  let lastError: unknown;

  for (let attempt = 1; attempt <= maxAttempts; attempt += 1) {
    try {
      const png = await bakeVisualizationPng(validated);
      const imageUrl = await storeVisualizationPng(contentHash, png);
      return attachStaticAsset(validated, {
        imageUrl,
        width,
        height,
        contentHash,
      });
    } catch (error) {
      lastError = error;
      if (attempt < maxAttempts) {
        await new Promise((resolve) => setTimeout(resolve, 1500 * attempt));
      }
    }
  }

  throw lastError instanceof Error
    ? lastError
    : new Error("visualization bake failed");
}

export async function bakeVisualizationBundle(params: {
  visualizationData: VisualizationData;
  solutionVisualizationData: VisualizationData;
  options?: VisualizationBakeOptions;
}): Promise<{
  visualizationData: VisualizationData;
  solutionVisualizationData: VisualizationData;
}> {
  const bakeOptions = params.options ?? {};
  let visualizationData = params.visualizationData;
  let solutionVisualizationData = params.solutionVisualizationData;

  if (visualizationData) {
    visualizationData = await bakeVisualizationData(visualizationData, bakeOptions);
  }
  if (solutionVisualizationData) {
    solutionVisualizationData = await bakeVisualizationData(
      solutionVisualizationData,
      bakeOptions,
    );
  }

  return { visualizationData, solutionVisualizationData };
}

function problemNeedsVisualizationBake(problem: GeneratedProblem): boolean {
  const normalized = normalizeProblemVisualization(problem);
  return (
    visualizationNeedsBaking(normalized.visualizationData) ||
    visualizationNeedsBaking(normalized.solutionVisualizationData)
  );
}

/** 저장용 — viz JSON만 두고 bake는 나중에 */
export function prepareGeneratedProblem(problem: GeneratedProblem): GeneratedProblem {
  const cleared = clearProblemVisualization(problem);
  const normalized = normalizeProblemVisualization(cleared);

  if (!problemNeedsVisualizationBake(normalized)) {
    return {
      ...normalized,
      visualizationMigrationStatus: "completed",
      visualizationMigrationError: null,
    };
  }

  return {
    ...normalized,
    visualizationMigrationStatus: "pending",
    visualizationMigrationError: null,
  };
}

export function prepareGeneratedProblems(
  problems: GeneratedProblem[],
): GeneratedProblem[] {
  return problems.map((problem) => prepareGeneratedProblem(problem));
}

export function prepareGeneratedProblemSet(
  problemSet: GeneratedProblemSet,
): GeneratedProblemSet {
  return {
    ...problemSet,
    problems: prepareGeneratedProblems(problemSet.problems),
  };
}

/** 단일 문제의 visualizationData / solutionVisualizationData를 PNG로 bake */
export async function bakeGeneratedProblem(
  problem: GeneratedProblem,
  options: VisualizationBakeOptions = {},
): Promise<GeneratedProblem> {
  const normalized = normalizeProblemVisualization(problem);

  if (options.skipBake || !problemNeedsVisualizationBake(normalized)) {
    return {
      ...normalized,
      visualizationMigrationStatus: "completed",
      visualizationMigrationError: null,
    };
  }

  try {
    const baked = await bakeVisualizationBundle({
      visualizationData: normalized.visualizationData,
      solutionVisualizationData: normalized.solutionVisualizationData,
      options,
    });
    return {
      ...normalized,
      visualizationData: baked.visualizationData,
      solutionVisualizationData: baked.solutionVisualizationData,
      visualizationMigrationStatus: "completed",
      visualizationMigrationError: null,
    };
  } catch (error) {
    return {
      ...normalized,
      visualizationData: null,
      solutionVisualizationData: null,
      visualizationMigrationStatus: "failed",
      visualizationMigrationError:
        error instanceof Error ? error.message : "visualization bake failed",
    };
  }
}

/** 문제 배열 bake — browser 인스턴스 1회 재사용 */
export async function bakeGeneratedProblems(
  problems: GeneratedProblem[],
  options: VisualizationBakeOptions = {},
): Promise<GeneratedProblem[]> {
  if (options.skipBake) {
    return problems.map((problem) => ({
      ...normalizeProblemVisualization(problem),
      visualizationMigrationStatus: "completed" as const,
      visualizationMigrationError: null,
    }));
  }

  const needsBake = problems.some((problem) => problemNeedsVisualizationBake(problem));
  if (!needsBake && !options.rebake) {
    return problems.map((problem) => normalizeProblemVisualization(problem));
  }

  return withVisualizationBaker(async () => {
    const baked: GeneratedProblem[] = [];
    for (const problem of problems) {
      baked.push(await bakeGeneratedProblem(problem, options));
    }
    return baked;
  });
}

/** problem set 저장 전 bake */
export async function bakeGeneratedProblemSet(
  problemSet: GeneratedProblemSet,
  options: VisualizationBakeOptions = {},
): Promise<GeneratedProblemSet> {
  const problems = await bakeGeneratedProblems(problemSet.problems, options);
  return { ...problemSet, problems };
}
