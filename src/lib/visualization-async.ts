import { getMongoDb } from "./mongodb";
import type { GeneratedProblem, GeneratedProblemSet, ProblemBankItem } from "./types";
import {
  prepareGeneratedProblem,
  prepareGeneratedProblemSet,
  prepareGeneratedProblems,
} from "./visualization-bake";
import { stripVisualizationIfNotRequired, stripVisualizationsIfNotRequired } from "./visualization-gate";
import { isVisualizationEnabled } from "./visualization-policy";
import { visualizationNeedsBaking } from "./visualization-schema";

const inFlightProblemSets = new Set<string>();
const inFlightBankItems = new Set<string>();

export {
  prepareGeneratedProblem,
  prepareGeneratedProblemSet,
  prepareGeneratedProblems,
} from "./visualization-bake";

async function bakeAndPersistProblemSet(problemSetId: string): Promise<void> {
  const { getProblemSet, updateProblemSet } = await import("./store");
  const { bakeGeneratedProblems } = await import("./visualization-bake");
  const current = await getProblemSet(problemSetId);
  if (!current) return;

  const gated = await stripVisualizationsIfNotRequired(current.problems);
  const baked = await bakeGeneratedProblems(gated);
  await updateProblemSet({ ...current, problems: baked });
}

async function bakeAndPersistBankItem(itemId: string): Promise<void> {
  const db = await getMongoDb();
  if (!db) return;

  const col = db.collection<ProblemBankItem>("problem_bank_items");
  const item = await col.findOne({ id: itemId });
  if (!item) return;

  const asProblem = {
    id: item.id,
    type: item.type,
    title: item.title,
    prompt: item.prompt,
    choices: item.choices,
    correctAnswer: item.correctAnswer,
    explanation: item.explanation,
    difficulty: item.difficulty,
    conceptTags: item.conceptTags,
    chart: item.chart,
    jsxGraph: item.jsxGraph,
    visualizationData: item.visualizationData,
    solutionVisualizationData: item.solutionVisualizationData,
    visualizationMigrationStatus: item.visualizationMigrationStatus,
    visualizationMigrationError: item.visualizationMigrationError,
  } as GeneratedProblem;

  const gated = await stripVisualizationIfNotRequired(asProblem);
  const { bakeGeneratedProblems } = await import("./visualization-bake");
  const [baked] = await bakeGeneratedProblems([gated]);

  await col.updateOne(
    { id: itemId },
    {
      $set: {
        visualizationData: baked.visualizationData,
        solutionVisualizationData: baked.solutionVisualizationData,
        visualizationMigrationStatus: baked.visualizationMigrationStatus,
        visualizationMigrationError: baked.visualizationMigrationError ?? null,
      },
    },
  );
}

/** 저장 직후 백그라운드 PNG bake (응답 블로킹 없음) */
export function scheduleProblemSetVisualizationBake(problemSetId: string): void {
  if (!isVisualizationEnabled()) return;
  if (inFlightProblemSets.has(problemSetId)) return;
  inFlightProblemSets.add(problemSetId);

  void bakeAndPersistProblemSet(problemSetId)
    .catch((error) => {
      console.error("[viz-async] problem set bake failed", problemSetId, error);
    })
    .finally(() => {
      inFlightProblemSets.delete(problemSetId);
    });
}

export function scheduleBankItemVisualizationBake(bankItemId: string): void {
  if (!isVisualizationEnabled()) return;
  if (inFlightBankItems.has(bankItemId)) return;
  inFlightBankItems.add(bankItemId);

  void bakeAndPersistBankItem(bankItemId)
    .catch((error) => {
      console.error("[viz-async] bank item bake failed", bankItemId, error);
    })
    .finally(() => {
      inFlightBankItems.delete(bankItemId);
    });
}

export function scheduleProblemSetVisualizationBakeIfNeeded(
  problemSet: GeneratedProblemSet,
): void {
  if (!isVisualizationEnabled()) return;
  const needs = problemSet.problems.some((problem) => {
    const normalized = prepareGeneratedProblem(problem);
    return (
      visualizationNeedsBaking(normalized.visualizationData) ||
      visualizationNeedsBaking(normalized.solutionVisualizationData)
    );
  });
  if (needs) scheduleProblemSetVisualizationBake(problemSet.id);
}

export function scheduleBankItemVisualizationBakeIfNeeded(item: ProblemBankItem): void {
  if (!isVisualizationEnabled()) return;
  if (
    visualizationNeedsBaking(item.visualizationData ?? null) ||
    visualizationNeedsBaking(item.solutionVisualizationData ?? null)
  ) {
    scheduleBankItemVisualizationBake(item.id);
  }
}
