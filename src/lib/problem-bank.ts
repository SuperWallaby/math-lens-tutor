import { randomUUID } from "crypto";

import type { AnalyzeQualityMode } from "./analyze-mode";
import { generateSimilarProblems, generateCurriculumUnitProblems, resolveAzureDeploymentName } from "./azure";
import {
  findCurriculumUnit,
  gradeToBand,
  matchUnitForConcept,
  type CurriculumUnit,
  type GradeBand,
} from "./curriculum";
import {
  findAvailableBankItems,
  findBankItemsByUnit,
  getActiveBankCountByUnit,
  getDeliveredBankItemIds,
  hashProblemContent,
  insertBankItem,
  invalidateUnitPoolCountCache,
  resolvePracticeMistakesForRelearn,
  savePracticeMistakeRecord,
  saveScannedProblemRecord,
  saveUserProblemDeliveries,
  updateDeliveryOutcome,
  usesMemoryProblemBankStore,
} from "./problem-bank-store";
import { studyLog } from "./server-log";
import { getSubmission } from "./store";
import type {
  GeneratedProblem,
  GeneratedProblemSet,
  PracticeMistakeRecord,
  ProblemAttempt,
  ProblemBankItem,
  ScannedProblemRecord,
  SolutionAnalysis,
  SolutionSubmission,
  UserProblemDelivery,
} from "./types";
import {
  meaningfulRecommendedFocus,
  meaningfulWeakConcepts,
  normalizeConceptTags,
} from "./types";
import { sanitizeGeneratedProblem } from "./problem-answer-sanitize";
import { calibrateProblemDifficulties, bumpDifficulty } from "./problem-difficulty";
import { prepareGeneratedProblems } from "./visualization-bake";
import { scheduleBankItemVisualizationBakeIfNeeded } from "./visualization-async";
import { trainingSubmissionId } from "./concept-training";

export type PracticeDifficultyBias = "same" | "harder";

function bankPickOptions(bias: PracticeDifficultyBias = "same") {
  if (bias === "harder") {
    return {
      minDifficulty: "medium" as const,
      preferHarder: true,
    };
  }
  return {};
}

function applyDifficultyBias(
  problems: GeneratedProblem[],
  bias: PracticeDifficultyBias,
): GeneratedProblem[] {
  if (bias !== "harder") return problems;
  return problems.map((problem) => ({
    ...problem,
    difficulty: bumpDifficulty(problem.difficulty),
  }));
}

const SET_SIZE = 5;

type UnitBankSelection = {
  fromBank: ProblemBankItem[];
  bankItems: ProblemBankItem[];
};

const unitSelectionCache = new Map<
  string,
  { expiresAt: number; selection: UnitBankSelection }
>();
const UNIT_SELECTION_TTL_MS = 30_000;

function unitSelectionCacheKey(
  userId: string,
  unitId: string,
  bias: PracticeDifficultyBias,
) {
  return `${userId}:${unitId}:${bias}`;
}

function peekUnitSelectionCache(
  userId: string,
  unitId: string,
  bias: PracticeDifficultyBias,
): UnitBankSelection | null {
  const key = unitSelectionCacheKey(userId, unitId, bias);
  const cached = unitSelectionCache.get(key);
  if (!cached || cached.expiresAt <= Date.now()) {
    unitSelectionCache.delete(key);
    return null;
  }
  return cached.selection;
}

function storeUnitSelectionCache(
  userId: string,
  unitId: string,
  bias: PracticeDifficultyBias,
  selection: UnitBankSelection,
) {
  unitSelectionCache.set(unitSelectionCacheKey(userId, unitId, bias), {
    expiresAt: Date.now() + UNIT_SELECTION_TTL_MS,
    selection,
  });
}

/** preview 직후 POST가 같은 선택을 재사용 — bank 조회 2회 → 1회 */
export function consumeUnitSelectionCache(
  userId: string,
  unitId: string,
  bias: PracticeDifficultyBias = "same",
): UnitBankSelection | null {
  const key = unitSelectionCacheKey(userId, unitId, bias);
  const cached = unitSelectionCache.get(key);
  unitSelectionCache.delete(key);
  if (!cached || cached.expiresAt <= Date.now()) return null;
  return cached.selection;
}

export type PracticeResolveMeta = {
  bankCount: number;
  setSize: number;
  needsGeneration: boolean;
  generateCount: number;
  newlyGeneratedCount: number;
  bankSelectMs: number;
  cacheHit?: boolean;
};

export type UnitPracticeResolveResult = {
  problemSet: GeneratedProblemSet;
  meta: PracticeResolveMeta;
};

const UNIT_BANK_POOL_TARGET = 10;

export function invalidateUnitSelectionCache(userId: string, unitId?: string) {
  if (!unitId) {
    for (const key of unitSelectionCache.keys()) {
      if (key.startsWith(`${userId}:`)) unitSelectionCache.delete(key);
    }
    return;
  }
  for (const key of unitSelectionCache.keys()) {
    if (key.startsWith(`${userId}:${unitId}:`)) unitSelectionCache.delete(key);
  }
}

export function extractConceptTagsFromAnalysis(analysis: SolutionAnalysis): string[] {
  const tags = [
    ...meaningfulWeakConcepts(analysis.weakConcepts),
    ...meaningfulRecommendedFocus(analysis.recommendedFocus),
  ];
  const normalized = tags
    .map((tag) => tag.trim())
    .filter(Boolean)
    .filter((tag, index, arr) => arr.indexOf(tag) === index);
  if (normalized.length > 0) return normalizeConceptTags(normalized);
  if (analysis.errorSummary.trim()) {
    return [analysis.errorSummary.trim().slice(0, 80)];
  }
  return ["수학 연습"];
}

export function pickPrimaryConcept(conceptTags: string[]): string {
  return conceptTags[0]?.trim() || "수학 연습";
}

export function bankItemToGeneratedProblem(
  item: ProblemBankItem,
  problemId: string,
): GeneratedProblem {
  return bankItemToProblem(item, problemId);
}

function bankItemToProblem(
  item: ProblemBankItem,
  problemId: string,
): GeneratedProblem {
  return {
    id: problemId,
    type: item.type,
    title: item.title,
    prompt: item.prompt,
    ...(item.type === "multiple_choice" && item.choices
      ? { choices: item.choices }
      : {}),
    correctAnswer: item.correctAnswer,
    explanation: item.explanation,
    difficulty: item.difficulty,
    conceptTags: item.conceptTags,
    chart: item.chart,
    jsxGraph: item.jsxGraph,
    visualizationData: item.visualizationData ?? null,
    solutionVisualizationData: item.solutionVisualizationData ?? null,
    visualizationMigrationStatus: item.visualizationMigrationStatus,
    visualizationMigrationError: item.visualizationMigrationError ?? null,
    source: "bank",
    bankItemId: item.id,
  };
}

function appendUniqueBankItems(
  target: ProblemBankItem[],
  candidates: ProblemBankItem[],
  limit: number,
) {
  const seen = new Set(target.map((item) => item.id));
  for (const item of candidates) {
    if (target.length >= limit) break;
    if (seen.has(item.id)) continue;
    target.push(item);
    seen.add(item.id);
  }
}

async function selectUnitBankItems(params: {
  userId: string;
  unit: CurriculumUnit;
  gradeBand: GradeBand;
  difficultyBias?: PracticeDifficultyBias;
  cacheResult?: boolean;
  useCache?: boolean;
}): Promise<UnitBankSelection> {
  const bias = params.difficultyBias ?? "same";
  if (params.useCache !== false) {
    const cached = peekUnitSelectionCache(params.userId, params.unit.id, bias);
    if (cached) return cached;
  }

  const bankOpts = bankPickOptions(bias);
  const unitConceptTags = normalizeConceptTags([
    params.unit.name,
    params.unit.subtitle,
    ...params.unit.keywords,
  ]);
  const poolCount = await getActiveBankCountByUnit(params.unit.id);
  const deliveredIds = (await usesMemoryProblemBankStore())
    ? await getDeliveredBankItemIds(params.userId)
    : undefined;

  let fromBank: ProblemBankItem[] = [];
  const bankItems: ProblemBankItem[] = [];

  if (poolCount > 0) {
    fromBank = await findBankItemsByUnit({
      userId: params.userId,
      gradeBand: params.gradeBand,
      unitId: params.unit.id,
      limit: SET_SIZE,
      deliveredIds,
      ...bankOpts,
    });
    bankItems.push(...fromBank);
  }

  if (bankItems.length < SET_SIZE) {
    const [broadFresh, reusableExact, reusableBroad] = await Promise.all([
      findAvailableBankItems({
        userId: params.userId,
        gradeBand: params.gradeBand,
        conceptTags: unitConceptTags,
        limit: SET_SIZE,
        deliveredIds,
        ...bankOpts,
      }),
      poolCount > 0
        ? findBankItemsByUnit({
            userId: params.userId,
            gradeBand: params.gradeBand,
            unitId: params.unit.id,
            limit: SET_SIZE,
            excludeDelivered: false,
            ...bankOpts,
          })
        : Promise.resolve([] as ProblemBankItem[]),
      findAvailableBankItems({
        userId: params.userId,
        gradeBand: params.gradeBand,
        conceptTags: unitConceptTags,
        limit: SET_SIZE,
        excludeDelivered: false,
        ...bankOpts,
      }),
    ]);

    appendUniqueBankItems(bankItems, broadFresh, SET_SIZE);
    appendUniqueBankItems(bankItems, reusableExact, SET_SIZE);
    appendUniqueBankItems(bankItems, reusableBroad, SET_SIZE);
  }

  const selection = { fromBank, bankItems };
  if (params.cacheResult !== false) {
    storeUnitSelectionCache(params.userId, params.unit.id, bias, selection);
  }
  return selection;
}

export async function probeUnitPracticeAvailability(params: {
  userId: string;
  unitId: string;
  difficultyBias?: PracticeDifficultyBias;
}): Promise<{
  unitId: string;
  unitName: string;
  bankCount: number;
  setSize: number;
  needsGeneration: boolean;
  generateCount: number;
  bankSelectMs: number;
}> {
  const started = Date.now();
  const located = findCurriculumUnit(params.unitId);
  if (!located) {
    throw new Error("단원을 찾을 수 없습니다.");
  }

  const { unit, gradeBand } = located;
  const { fromBank, bankItems } = await selectUnitBankItems({
    userId: params.userId,
    unit,
    gradeBand,
    difficultyBias: params.difficultyBias,
  });

  const bankSelectMs = Date.now() - started;
  const bankCount = bankItems.length;
  const generateCount = Math.max(0, SET_SIZE - bankCount);

  studyLog("problem-bank", "unit-probe", {
    userId: params.userId,
    unitId: unit.id,
    gradeBand,
    fromBank: fromBank.length,
    bankCount,
    generateCount,
    bankSelectMs,
  });

  return {
    unitId: unit.id,
    unitName: unit.name,
    bankCount,
    setSize: SET_SIZE,
    needsGeneration: generateCount > 0,
    generateCount,
    bankSelectMs,
  };
}

export async function ingestGeneratedProblems(params: {
  problems: GeneratedProblem[];
  gradeBand: string;
  unitId?: string;
  originSubmissionId?: string;
  source?: ProblemBankItem["source"];
}): Promise<ProblemBankItem[]> {
  const stored: ProblemBankItem[] = [];
  const source = params.source ?? "ai_generated";
  const band = params.gradeBand as GradeBand;

  const calibrated = calibrateProblemDifficulties(
    params.problems.map((raw) => sanitizeGeneratedProblem(raw)),
    { gradeBand: band, unitId: params.unitId },
  );
  const prepared = prepareGeneratedProblems(calibrated);

  for (const problem of prepared) {
    const conceptTags = normalizeConceptTags(problem.conceptTags);
    const contentHash = hashProblemContent({
      prompt: problem.prompt,
      correctAnswer: problem.correctAnswer,
      conceptTags,
    });

    const item: ProblemBankItem = {
      id: randomUUID(),
      contentHash,
      type: problem.type,
      title: problem.title,
      prompt: problem.prompt,
      ...(problem.type === "multiple_choice" && problem.choices
        ? { choices: problem.choices }
        : {}),
      correctAnswer: problem.correctAnswer,
      explanation: problem.explanation,
      difficulty: problem.difficulty,
      conceptTags,
      conceptPrimary: pickPrimaryConcept(conceptTags),
      gradeBand: params.gradeBand,
      unitId: params.unitId,
      source,
      originSubmissionId: params.originSubmissionId,
      active: true,
      deliveryCount: 0,
      chart: problem.chart,
      jsxGraph: problem.jsxGraph,
      visualizationData: problem.visualizationData ?? null,
      solutionVisualizationData: problem.solutionVisualizationData ?? null,
      visualizationMigrationStatus:
        problem.visualizationMigrationStatus ?? "completed",
      visualizationMigrationError: problem.visualizationMigrationError ?? null,
      createdAt: new Date().toISOString(),
    };

    const saved = await insertBankItem(item);
    stored.push(saved);
    scheduleBankItemVisualizationBakeIfNeeded(saved);
  }

  return stored;
}

export async function recordDeliveriesForProblems(params: {
  userId: string;
  submissionId: string;
  problemSetId: string;
  problems: GeneratedProblem[];
}): Promise<void> {
  const deliveries: UserProblemDelivery[] = [];

  for (const problem of params.problems) {
    if (!problem.bankItemId) continue;
    deliveries.push({
      id: randomUUID(),
      userId: params.userId,
      bankItemId: problem.bankItemId,
      problemSetId: params.problemSetId,
      submissionId: params.submissionId,
      problemId: problem.id,
      deliveredAt: new Date().toISOString(),
      outcome: "pending",
    });
  }

  await saveUserProblemDeliveries(deliveries);
}

export async function resolvePracticeProblemSet(params: {
  userId: string;
  analysis: SolutionAnalysis;
  submissionId: string;
  problemSetId: string;
  grade?: string | null;
  generateOptions: {
    deploymentName: string;
    mode: AnalyzeQualityMode;
    fromVisionOcrOnly?: boolean;
  };
  difficultyBias?: PracticeDifficultyBias;
}): Promise<GeneratedProblemSet> {
  const conceptTags = extractConceptTagsFromAnalysis(params.analysis);
  const gradeBand = gradeToBand(params.grade);
  const bias = params.difficultyBias ?? "same";
  const bankOpts = bankPickOptions(bias);
  const fromBank = await findAvailableBankItems({
    userId: params.userId,
    gradeBand,
    conceptTags,
    limit: SET_SIZE,
    ...bankOpts,
  });

  studyLog("problem-bank", "select", {
    userId: params.userId,
    gradeBand,
    conceptTags,
    fromBank: fromBank.length,
  });

  const problems: GeneratedProblem[] = fromBank.map((item) =>
    bankItemToProblem(item, randomUUID()),
  );

  const needed = SET_SIZE - problems.length;
  let newlyGeneratedCount = 0;
  if (needed > 0) {
    const generatedSet = await generateSimilarProblems(
      params.analysis,
      params.submissionId,
      {
        deploymentName: params.generateOptions.deploymentName,
        mode: params.generateOptions.mode,
        problemSetId: params.problemSetId,
        fromVisionOcrOnly: params.generateOptions.fromVisionOcrOnly,
        problemCount: needed,
        gradeBand,
        preferHarder: bias === "harder",
      },
    );

    const ingested = await ingestGeneratedProblems({
      problems: generatedSet.problems,
      gradeBand,
      originSubmissionId: params.submissionId,
    });
    newlyGeneratedCount = ingested.length;

    for (let i = 0; i < generatedSet.problems.length; i += 1) {
      const bankItem = ingested[i];
      if (!bankItem) continue;
      problems.push(
        bankItemToProblem(bankItem, randomUUID()),
      );
    }
  }

  const title =
    conceptTags.length > 0
      ? `${pickPrimaryConcept(conceptTags)} 유사문제 훈련`
      : "유사문제 훈련";
  const learningGoal =
    meaningfulRecommendedFocus(params.analysis.recommendedFocus)[0] ??
    meaningfulWeakConcepts(params.analysis.weakConcepts)[0] ??
    "틀린 유형을 반복 연습해 개념을 익힙니다.";

  const problemSet: GeneratedProblemSet = {
    id: params.problemSetId,
    submissionId: params.submissionId,
    title,
    learningGoal,
    problems: applyDifficultyBias(
      calibrateProblemDifficulties(problems.slice(0, SET_SIZE), {
        gradeBand,
        unitId: matchUnitForConcept(conceptTags[0] ?? "", params.grade)?.id,
      }),
      bias,
    ),
  };

  await recordDeliveriesForProblems({
    userId: params.userId,
    submissionId: params.submissionId,
    problemSetId: params.problemSetId,
    problems: problemSet.problems,
  });

  studyLog("problem-bank", "deliver", {
    userId: params.userId,
    problemSetId: params.problemSetId,
    reusedFromBankCount: fromBank.length,
    newlyGeneratedCount,
  });

  return problemSet;
}

export async function resolveUnitPracticeProblemSet(params: {
  userId: string;
  unitId: string;
  problemSetId: string;
  generateOptions: {
    deploymentName: string;
    mode: AnalyzeQualityMode;
  };
  difficultyBias?: PracticeDifficultyBias;
}): Promise<UnitPracticeResolveResult> {
  const selectStarted = Date.now();
  const located = findCurriculumUnit(params.unitId);
  if (!located) {
    throw new Error("단원을 찾을 수 없습니다.");
  }

  const { unit, gradeBand } = located;
  const submissionId = `unit:${unit.id}`;
  const bias = params.difficultyBias ?? "same";
  const cachedSelection = consumeUnitSelectionCache(params.userId, unit.id, bias);
  const { fromBank, bankItems } =
    cachedSelection ??
    (await selectUnitBankItems({
      userId: params.userId,
      unit,
      gradeBand,
      difficultyBias: bias,
      cacheResult: false,
    }));

  const bankSelectMs = Date.now() - selectStarted;

  studyLog("problem-bank", "unit-select", {
    userId: params.userId,
    unitId: unit.id,
    gradeBand,
    fromBank: fromBank.length,
    reusedAfterFallback: bankItems.length,
    cacheHit: Boolean(cachedSelection),
    bankSelectMs,
  });

  const problems: GeneratedProblem[] = bankItems.map((item) =>
    bankItemToProblem(item, randomUUID()),
  );

  const needed = SET_SIZE - problems.length;
  let newlyGeneratedCount = 0;
  if (needed > 0) {
    const generatedSet = await generateCurriculumUnitProblems(unit, gradeBand, {
      deploymentName: params.generateOptions.deploymentName,
      mode: params.generateOptions.mode,
      problemSetId: params.problemSetId,
      problemCount: needed,
      preferHarder: bias === "harder",
    });

    const ingested = await ingestGeneratedProblems({
      problems: generatedSet.problems,
      gradeBand,
      unitId: unit.id,
      originSubmissionId: submissionId,
    });
    newlyGeneratedCount = ingested.length;

    for (let i = 0; i < generatedSet.problems.length; i += 1) {
      const bankItem = ingested[i];
      if (!bankItem) continue;
      problems.push(bankItemToProblem(bankItem, randomUUID()));
    }
  }

  const problemSet: GeneratedProblemSet = {
    id: params.problemSetId,
    submissionId,
    title: `${unit.name} 연습`,
    learningGoal: unit.subtitle || `${unit.section} 단원 개념을 익힙니다.`,
    problems: applyDifficultyBias(
      calibrateProblemDifficulties(problems.slice(0, SET_SIZE), {
        gradeBand,
        unitId: unit.id,
      }),
      bias,
    ),
  };

  await recordDeliveriesForProblems({
    userId: params.userId,
    submissionId,
    problemSetId: params.problemSetId,
    problems: problemSet.problems,
  });

  invalidateUnitSelectionCache(params.userId, unit.id);

  studyLog("problem-bank", "unit-deliver", {
    userId: params.userId,
    unitId: unit.id,
    problemSetId: params.problemSetId,
    reusedFromBankCount: bankItems.length,
    newlyGeneratedCount,
  });

  if (newlyGeneratedCount > 0) {
    scheduleUnitBankTopUp(unit.id, gradeBand);
  }

  const meta: PracticeResolveMeta = {
    bankCount: bankItems.length,
    setSize: SET_SIZE,
    needsGeneration: needed > 0,
    generateCount: Math.max(0, needed),
    newlyGeneratedCount,
    bankSelectMs,
    cacheHit: Boolean(cachedSelection),
  };

  return { problemSet, meta };
}

export async function maybeTopUpUnitBankPool(params: {
  unitId: string;
  gradeBand: GradeBand;
  targetCount?: number;
  deploymentName?: string;
  mode?: AnalyzeQualityMode;
}): Promise<number> {
  const target = params.targetCount ?? UNIT_BANK_POOL_TARGET;
  const existing = await getActiveBankCountByUnit(params.unitId);
  if (existing >= target) return 0;

  const located = findCurriculumUnit(params.unitId);
  if (!located) return 0;

  const deploymentName =
    params.deploymentName?.trim() ||
    resolveAzureDeploymentName(params.mode ?? "balanced") ||
    "";
  if (!deploymentName) return 0;

  const need = target - existing;
  studyLog("problem-bank", "top-up start", {
    unitId: params.unitId,
    existing,
    need,
  });

  const inserted = await seedCurriculumUnitProblems({
    unit: located.unit,
    gradeBand: located.gradeBand,
    count: need,
    deploymentName,
    mode: params.mode ?? "balanced",
  });
  invalidateUnitPoolCountCache(params.unitId);
  studyLog("problem-bank", "top-up done", {
    unitId: params.unitId,
    inserted,
  });
  return inserted;
}

export function scheduleUnitBankTopUp(unitId: string, gradeBand: GradeBand) {
  void maybeTopUpUnitBankPool({ unitId, gradeBand }).catch((error) => {
    studyLog("problem-bank", "top-up failed", {
      unitId,
      error: error instanceof Error ? error.message : String(error),
    });
  });
}

export async function probeTrainingPracticeAvailability(params: {
  userId: string;
  focusConcepts: string[];
  grade?: string | null;
}): Promise<{
  bankCount: number;
  setSize: number;
  needsGeneration: boolean;
  generateCount: number;
  bankSelectMs: number;
}> {
  const started = Date.now();
  const conceptTags = normalizeConceptTags(
    params.focusConcepts.filter((value) => value.trim()),
  );
  if (conceptTags.length === 0) {
    throw new Error("훈련할 개념이 없습니다.");
  }

  const gradeBand = gradeToBand(params.grade);
  const fromBank = await findAvailableBankItems({
    userId: params.userId,
    gradeBand,
    conceptTags,
    limit: SET_SIZE,
  });

  const bankSelectMs = Date.now() - started;
  const bankCount = fromBank.length;
  const generateCount = Math.max(0, SET_SIZE - bankCount);

  studyLog("problem-bank", "training-probe", {
    userId: params.userId,
    gradeBand,
    conceptTags,
    bankCount,
    generateCount,
    bankSelectMs,
  });

  return {
    bankCount,
    setSize: SET_SIZE,
    needsGeneration: generateCount > 0,
    generateCount,
    bankSelectMs,
  };
}

function syntheticAnalysisForConcepts(concepts: string[]): SolutionAnalysis {
  const focus = concepts.filter((value) => value.trim()).slice(0, 3);
  const primary = pickPrimaryConcept(focus);
  return {
    problemText: `${primary} 보완 훈련`,
    extractedStudentAnswer: "",
    inferredCorrectAnswer: "",
    confidence: 0.5,
    solutionSteps: [],
    referenceSolutionSteps: [],
    errorSummary: `${primary} 개념에서 반복 오답이 있어 복습이 필요합니다.`,
    weakConcepts: focus.length > 0 ? focus : [primary],
    recommendedFocus: focus.length > 0 ? focus : [primary],
    imageQualityWarning: false,
  };
}

export type TrainingPracticeResolveResult = {
  problemSet: GeneratedProblemSet;
  meta: PracticeResolveMeta;
};

export async function resolveTrainingProblemSet(params: {
  userId: string;
  problemSetId: string;
  focusConcepts: string[];
  grade?: string | null;
  generateOptions: {
    deploymentName: string;
    mode: AnalyzeQualityMode;
  };
}): Promise<TrainingPracticeResolveResult> {
  const selectStarted = Date.now();
  const conceptTags = normalizeConceptTags(
    params.focusConcepts.filter((value) => value.trim()),
  );
  if (conceptTags.length === 0) {
    throw new Error("훈련할 개념이 없습니다.");
  }

  const gradeBand = gradeToBand(params.grade);
  const submissionId = trainingSubmissionId(params.userId);
  const fromBank = await findAvailableBankItems({
    userId: params.userId,
    gradeBand,
    conceptTags,
    limit: SET_SIZE,
  });
  const bankSelectMs = Date.now() - selectStarted;

  studyLog("problem-bank", "training-select", {
    userId: params.userId,
    gradeBand,
    conceptTags,
    fromBank: fromBank.length,
    bankSelectMs,
  });

  const problems: GeneratedProblem[] = fromBank.map((item) =>
    bankItemToProblem(item, randomUUID()),
  );

  const needed = SET_SIZE - problems.length;
  let newlyGeneratedCount = 0;
  if (needed > 0) {
    const analysis = syntheticAnalysisForConcepts(conceptTags);
    const generatedSet = await generateSimilarProblems(
      analysis,
      submissionId,
      {
        deploymentName: params.generateOptions.deploymentName,
        mode: params.generateOptions.mode,
        problemSetId: params.problemSetId,
        problemCount: needed,
        gradeBand,
      },
    );

    const unitMatch = matchUnitForConcept(pickPrimaryConcept(conceptTags), params.grade);
    const ingested = await ingestGeneratedProblems({
      problems: generatedSet.problems,
      gradeBand,
      unitId: unitMatch?.id,
      originSubmissionId: submissionId,
    });
    newlyGeneratedCount = ingested.length;

    for (let i = 0; i < generatedSet.problems.length; i += 1) {
      const bankItem = ingested[i];
      if (!bankItem) continue;
      problems.push(bankItemToProblem(bankItem, randomUUID()));
    }
  }

  const primary = pickPrimaryConcept(conceptTags);
  const problemSet: GeneratedProblemSet = {
    id: params.problemSetId,
    submissionId,
    title: `${primary} 복습 훈련`,
    learningGoal: `틀렸던 ${conceptTags.slice(0, 2).join(", ")} 개념을 다시 연습합니다.`,
    problems: calibrateProblemDifficulties(problems.slice(0, SET_SIZE), {
      gradeBand,
      unitId: matchUnitForConcept(primary, params.grade)?.id,
    }),
  };

  await recordDeliveriesForProblems({
    userId: params.userId,
    submissionId,
    problemSetId: params.problemSetId,
    problems: problemSet.problems,
  });

  studyLog("problem-bank", "training-deliver", {
    userId: params.userId,
    problemSetId: params.problemSetId,
    reusedFromBankCount: fromBank.length,
    newlyGeneratedCount,
  });

  const unitMatch = matchUnitForConcept(primary, params.grade);
  if (newlyGeneratedCount > 0 && unitMatch?.id) {
    scheduleUnitBankTopUp(unitMatch.id, gradeBand);
  }

  const meta: PracticeResolveMeta = {
    bankCount: fromBank.length,
    setSize: SET_SIZE,
    needsGeneration: needed > 0,
    generateCount: Math.max(0, needed),
    newlyGeneratedCount,
    bankSelectMs,
  };

  return { problemSet, meta };
}

export async function seedCurriculumUnitProblems(params: {
  unit: CurriculumUnit;
  gradeBand: GradeBand;
  count: number;
  deploymentName: string;
  mode: AnalyzeQualityMode;
}): Promise<number> {
  const generatedSet = await generateCurriculumUnitProblems(
    params.unit,
    params.gradeBand,
    {
      deploymentName: params.deploymentName,
      mode: params.mode,
      problemCount: params.count,
    },
  );

  const ingested = await ingestGeneratedProblems({
    problems: generatedSet.problems,
    gradeBand: params.gradeBand,
    unitId: params.unit.id,
    originSubmissionId: `seed:${params.unit.id}`,
    source: "imported",
  });

  return ingested.length;
}

async function pickReplacementBankItem(params: {
  userId: string;
  problemSet: GeneratedProblemSet;
  current: GeneratedProblem;
  gradeBand: GradeBand;
  harder: boolean;
}): Promise<ProblemBankItem | null> {
  const bankOpts = bankPickOptions(params.harder ? "harder" : "same");
  const minDifficulty = params.harder
    ? bumpDifficulty(params.current.difficulty)
    : undefined;
  const exclude = new Set(
    params.problemSet.problems
      .map((problem) => problem.bankItemId)
      .filter((id): id is string => Boolean(id)),
  );
  const conceptTags = normalizeConceptTags(params.current.conceptTags);

  let candidates: ProblemBankItem[] = [];
  if (params.problemSet.submissionId.startsWith("unit:")) {
    const unitId = params.problemSet.submissionId.slice("unit:".length);
    candidates = await findBankItemsByUnit({
      userId: params.userId,
      gradeBand: params.gradeBand,
      unitId,
      limit: 24,
      minDifficulty,
      preferHarder: bankOpts.preferHarder,
    });
  } else {
    candidates = await findAvailableBankItems({
      userId: params.userId,
      gradeBand: params.gradeBand,
      conceptTags,
      limit: 24,
      minDifficulty,
      preferHarder: bankOpts.preferHarder,
    });
  }

  return candidates.find((item) => !exclude.has(item.id)) ?? null;
}

/**
 * 실제 제출(submission)이 없는 문항(예: 맞춤 피드)에서 유사 문제를 생성할 때
 * 사용할 최소 분석 객체를 현재 문항으로부터 합성한다.
 */
function buildSyntheticAnalysisFromProblem(
  problem: GeneratedProblem,
  conceptTags: string[],
): SolutionAnalysis {
  return {
    problemText: problem.prompt,
    extractedStudentAnswer: "",
    inferredCorrectAnswer: problem.correctAnswer ?? "",
    confidence: 0.5,
    solutionSteps: [],
    referenceSolutionSteps: [],
    errorSummary: "",
    weakConcepts: conceptTags,
    recommendedFocus: conceptTags,
    imageQualityWarning: false,
  };
}

export async function replacePracticeProblem(params: {
  userId: string;
  problemSet: GeneratedProblemSet;
  problemId: string;
  harder: boolean;
  grade?: string | null;
  generateOptions: {
    deploymentName: string;
    mode: AnalyzeQualityMode;
  };
}): Promise<{ problemSet: GeneratedProblemSet; problem: GeneratedProblem }> {
  const index = params.problemSet.problems.findIndex(
    (problem) => problem.id === params.problemId,
  );
  if (index < 0) {
    throw new Error("문제를 찾을 수 없습니다.");
  }

  const current = params.problemSet.problems[index]!;
  const gradeBand = gradeToBand(params.grade);
  const bias: PracticeDifficultyBias = params.harder ? "harder" : "same";
  let replacement: GeneratedProblem | null = null;

  const bankItem = await pickReplacementBankItem({
    userId: params.userId,
    problemSet: params.problemSet,
    current,
    gradeBand,
    harder: params.harder,
  });

  if (bankItem) {
    replacement = bankItemToProblem(bankItem, randomUUID());
  } else if (params.problemSet.submissionId.startsWith("unit:")) {
    const unitId = params.problemSet.submissionId.slice("unit:".length);
    const located = findCurriculumUnit(unitId);
    if (!located) throw new Error("단원을 찾을 수 없습니다.");
    const generated = await generateCurriculumUnitProblems(
      located.unit,
      located.gradeBand,
      {
        deploymentName: params.generateOptions.deploymentName,
        mode: params.generateOptions.mode,
        problemCount: 1,
        preferHarder: params.harder,
      },
    );
    const ingested = await ingestGeneratedProblems({
      problems: generated.problems,
      gradeBand: located.gradeBand,
      unitId: located.unit.id,
      originSubmissionId: params.problemSet.submissionId,
    });
    if (ingested[0]) {
      replacement = bankItemToProblem(ingested[0]!, randomUUID());
    }
  } else if (params.problemSet.submissionId.startsWith("feed:")) {
    // 맞춤 피드 문제는 실제 제출(submission) 레코드가 없으므로 원본 분석을 조회할 수 없다.
    // 현재 문항의 개념으로 합성 분석을 만들어 유사 문제를 새로 생성한다.
    const conceptTags = normalizeConceptTags(current.conceptTags);
    const generated = await generateSimilarProblems(
      buildSyntheticAnalysisFromProblem(current, conceptTags),
      params.problemSet.submissionId,
      {
        deploymentName: params.generateOptions.deploymentName,
        mode: params.generateOptions.mode,
        problemCount: 1,
        gradeBand,
        preferHarder: params.harder,
      },
    );
    const ingested = await ingestGeneratedProblems({
      problems: generated.problems,
      gradeBand,
      originSubmissionId: params.problemSet.submissionId,
    });
    if (ingested[0]) {
      replacement = bankItemToProblem(ingested[0]!, randomUUID());
    }
  } else {
    const submission = await getSubmission(params.problemSet.submissionId);
    if (!submission) {
      throw new Error("원본 분석을 찾을 수 없습니다.");
    }
    const generated = await generateSimilarProblems(
      submission.analysis,
      params.problemSet.submissionId,
      {
        deploymentName: params.generateOptions.deploymentName,
        mode: params.generateOptions.mode,
        problemCount: 1,
        gradeBand,
        preferHarder: params.harder,
      },
    );
    const ingested = await ingestGeneratedProblems({
      problems: generated.problems,
      gradeBand,
      originSubmissionId: params.problemSet.submissionId,
    });
    if (ingested[0]) {
      replacement = bankItemToProblem(ingested[0]!, randomUUID());
    }
  }

  if (!replacement) {
    throw new Error("새 문제를 만들지 못했습니다.");
  }

  replacement = applyDifficultyBias([replacement], bias)[0]!;
  const problems = [...params.problemSet.problems];
  problems[index] = replacement;

  const problemSet: GeneratedProblemSet = {
    ...params.problemSet,
    problems,
  };

  await recordDeliveriesForProblems({
    userId: params.userId,
    submissionId: params.problemSet.submissionId,
    problemSetId: params.problemSet.id,
    problems: [replacement],
  });

  studyLog("problem-bank", "replace-problem", {
    userId: params.userId,
    setId: params.problemSet.id,
    problemId: params.problemId,
    harder: params.harder,
    bankItemId: replacement.bankItemId,
  });

  return { problemSet, problem: replacement };
}

export async function indexScannedSubmission(
  submission: SolutionSubmission,
  grade?: string | null,
): Promise<ScannedProblemRecord> {
  const conceptTags = extractConceptTagsFromAnalysis(submission.analysis);
  const record: ScannedProblemRecord = {
    id: randomUUID(),
    userId: submission.userId,
    submissionId: submission.id,
    imageUrl: submission.imageUrl,
    imageName: submission.imageName,
    problemText: submission.analysis.problemText,
    extractedStudentAnswer: submission.analysis.extractedStudentAnswer,
    inferredCorrectAnswer: submission.analysis.inferredCorrectAnswer,
    errorSummary: submission.analysis.errorSummary,
    solutionSteps: submission.analysis.solutionSteps,
    weakConcepts: meaningfulWeakConcepts(submission.analysis.weakConcepts),
    recommendedFocus: meaningfulRecommendedFocus(submission.analysis.recommendedFocus),
    conceptTags,
    conceptPrimary: pickPrimaryConcept(conceptTags),
    gradeBand: gradeToBand(grade),
    createdAt: submission.createdAt,
  };

  return saveScannedProblemRecord(record);
}

export async function recordPracticeAttempt(params: {
  attempt: ProblemAttempt;
  problem: GeneratedProblem;
  expectedAnswer: string;
}): Promise<string[]> {
  if (params.problem.bankItemId) {
    await updateDeliveryOutcome({
      userId: params.attempt.userId,
      bankItemId: params.problem.bankItemId,
      problemSetId: params.attempt.setId,
      problemId: params.attempt.problemId,
      outcome: params.attempt.isCorrect ? "correct" : "incorrect",
      attemptId: params.attempt.id,
    });
  }

  const conceptTags = normalizeConceptTags(params.problem.conceptTags);

  if (params.attempt.isCorrect) {
    return resolvePracticeMistakesForRelearn({
      userId: params.attempt.userId,
      conceptTags,
      conceptPrimary: pickPrimaryConcept(conceptTags),
      attemptId: params.attempt.id,
    });
  }

  const mistake: PracticeMistakeRecord = {
    id: randomUUID(),
    userId: params.attempt.userId,
    attemptId: params.attempt.id,
    setId: params.attempt.setId,
    problemId: params.attempt.problemId,
    bankItemId: params.problem.bankItemId,
    answer: params.attempt.answer,
    expectedAnswer: params.expectedAnswer,
    conceptTags,
    conceptPrimary: pickPrimaryConcept(conceptTags),
    feedback: params.attempt.feedback,
    createdAt: params.attempt.createdAt,
  };

  await savePracticeMistakeRecord(mistake);
  return [];
}
