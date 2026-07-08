#!/usr/bin/env node
/**
 * 전체 문제풀: 본문만 보고 "풀이에 그래프·도형이 꼭 필요한가?" 판단 후 불필요 viz 제거
 *
 *   npm run audit:unnecessary-viz:fix-all          ← 이거 한 줄 (전체 감사 + 제거)
 *   npm run audit:unnecessary-viz -- --apply --target all
 *   npm run audit:unnecessary-viz -- --limit 20      # 샘플만
 *   npm run audit:unnecessary-viz:apply              # 저장된 JSON 기준 제거
 */
import { existsSync, mkdirSync, readFileSync, writeFileSync } from "fs";
import { join } from "path";
import type { Collection, Document } from "mongodb";

import { completeAzureJsonPrompt } from "../src/lib/azure";
import { env } from "../src/lib/env";
import { getMongoDb } from "../src/lib/mongodb";
import { buildVisualizationAuditUserPrompt } from "../src/lib/visualization-needed-prompt";
import type { GeneratedProblem, GeneratedProblemSet, ProblemBankItem } from "../src/lib/types";

type Target = "bank" | "sets" | "all";

type ProblemFields = {
  title: string;
  prompt: string;
  explanation: string;
  conceptTags: string[];
  visualizationData?: GeneratedProblem["visualizationData"];
  solutionVisualizationData?: GeneratedProblem["solutionVisualizationData"];
};

type FlaggedBank = {
  source: "bank";
  id: string;
  title: string;
  reason: string;
  promptPreview: string;
};

type FlaggedSetProblem = {
  source: "set";
  setId: string;
  id: string;
  title: string;
  reason: string;
  promptPreview: string;
};

type FlaggedItem = FlaggedBank | FlaggedSetProblem;

type AuditReport = {
  criterion: string;
  target: Target;
  bank: { withViz: number; audited: number; flagged: FlaggedBank[] };
  sets: { withViz: number; audited: number; flagged: FlaggedSetProblem[] };
  flagged: number;
};

function reportPath() {
  return join(process.cwd(), "artifacts/audit-unnecessary-viz.json");
}

function parseArgs(argv: string[]) {
  const limitFlag = argv.indexOf("--limit");
  const idFlag = argv.indexOf("--id");
  const targetFlag = argv.indexOf("--target");
  let target: Target = "all";
  if (targetFlag >= 0) {
    const value = argv[targetFlag + 1];
    if (value === "bank" || value === "sets" || value === "all") target = value;
  }
  return {
    limit:
      limitFlag >= 0 ? Number(argv[limitFlag + 1]) || 30 : Number.POSITIVE_INFINITY,
    id: idFlag >= 0 ? argv[idFlag + 1] : undefined,
    target,
    apply: argv.includes("--apply"),
    applyFromReport: argv.includes("--apply-from-report"),
    dryRun: argv.includes("--dry-run"),
  };
}

function parseJsonFromText(text: string) {
  const fenced = text.match(/```(?:json)?\s*([\s\S]*?)```/);
  const jsonText = fenced?.[1] ?? text;
  return JSON.parse(jsonText.trim()) as Record<string, unknown>;
}

function hasViz(problem: ProblemFields): boolean {
  return Boolean(problem.visualizationData || problem.solutionVisualizationData);
}

async function isGraphRequiredToSolve(problem: ProblemFields): Promise<{
  graphRequiredToSolve: boolean;
  reason: string;
}> {
  const deployment = env.azureOpenAiDeployment?.trim();
  if (!deployment) throw new Error("Azure OpenAI not configured");

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

async function auditProblem(
  problem: ProblemFields,
  meta: { source: "bank"; id: string } | { source: "set"; setId: string; id: string },
): Promise<FlaggedItem | null> {
  if (!hasViz(problem)) return null;

  const { graphRequiredToSolve, reason } = await isGraphRequiredToSolve(problem);
  if (graphRequiredToSolve) return null;

  const promptPreview = problem.prompt.slice(0, 160).replace(/\s+/g, " ");
  if (meta.source === "bank") {
    return { source: "bank", id: meta.id, title: problem.title, reason, promptPreview };
  }
  return {
    source: "set",
    setId: meta.setId,
    id: meta.id,
    title: problem.title,
    reason,
    promptPreview,
  };
}

async function auditBank(
  db: Awaited<ReturnType<typeof getMongoDb>>,
  options: ReturnType<typeof parseArgs>,
) {
  const flagged: FlaggedBank[] = [];
  const filter: Record<string, unknown> = {
    active: true,
    $or: [
      { visualizationData: { $ne: null } },
      { solutionVisualizationData: { $ne: null } },
    ],
  };
  if (options.id) filter.id = options.id;

  const items = await db!
    .collection<ProblemBankItem>("problem_bank_items")
    .find(filter, {
      projection: {
        id: 1,
        title: 1,
        prompt: 1,
        explanation: 1,
        conceptTags: 1,
        visualizationData: 1,
        solutionVisualizationData: 1,
      },
    })
    .toArray();

  let audited = 0;
  for (const item of items) {
    if (audited >= options.limit) break;
    audited += 1;
    try {
      const row = await auditProblem(item, { source: "bank", id: item.id });
      if (row && row.source === "bank") {
        flagged.push(row);
        console.log(`[bank 불필요] ${item.title}: ${row.reason}`);
      } else if (hasViz(item)) {
        console.log(`[bank 필요] ${item.title}`);
      }
    } catch (error) {
      console.error(
        `[bank fail] ${item.id} · ${item.title}:`,
        error instanceof Error ? error.message : error,
      );
    }
  }

  return { withViz: items.length, audited, flagged };
}

async function auditSets(db: Awaited<ReturnType<typeof getMongoDb>>, options: ReturnType<typeof parseArgs>) {
  const flagged: FlaggedSetProblem[] = [];
  const sets = await db!
    .collection<GeneratedProblemSet>("generated_problem_sets")
    .find(
      {
        $or: [
          { "problems.visualizationData": { $ne: null } },
          { "problems.solutionVisualizationData": { $ne: null } },
        ],
      },
      { projection: { id: 1, title: 1, problems: 1 } },
    )
    .toArray();

  const problemsWithViz: Array<{ set: GeneratedProblemSet; problem: GeneratedProblem }> = [];
  for (const set of sets) {
    for (const problem of set.problems ?? []) {
      if (!hasViz(problem)) continue;
      if (options.id && problem.id !== options.id) continue;
      problemsWithViz.push({ set, problem });
    }
  }

  let audited = 0;
  for (const { set, problem } of problemsWithViz) {
    if (audited >= options.limit) break;
    audited += 1;
    try {
      const row = await auditProblem(problem, {
        source: "set",
        setId: set.id,
        id: problem.id,
      });
      if (row && row.source === "set") {
        flagged.push(row);
        console.log(`[set 불필요] ${set.title} / ${problem.title}: ${row.reason}`);
      } else if (hasViz(problem)) {
        console.log(`[set 필요] ${set.title} / ${problem.title}`);
      }
    } catch (error) {
      console.error(
        `[set fail] ${set.id}/${problem.id} · ${problem.title}:`,
        error instanceof Error ? error.message : error,
      );
    }
  }

  return { withViz: problemsWithViz.length, audited, flagged };
}

async function removeFromBank(
  col: Collection<Document>,
  flagged: FlaggedBank[],
  dryRun: boolean,
) {
  let removed = 0;
  for (const row of flagged) {
    if (dryRun) {
      console.log(`[dry-run bank] ${row.id} · ${row.title}`);
      removed += 1;
      continue;
    }
    const result = await col.updateOne(
      { id: row.id },
      {
        $set: {
          visualizationData: null,
          solutionVisualizationData: null,
          visualizationMigrationStatus: "completed",
          visualizationMigrationError: null,
        },
      },
    );
    if (result.matchedCount > 0) {
      removed += 1;
      console.log(`[removed bank] ${row.id} · ${row.title}`);
    }
  }
  return removed;
}

async function removeFromSets(
  col: Collection<Document>,
  flagged: FlaggedSetProblem[],
  dryRun: boolean,
) {
  const bySet = new Map<string, Set<string>>();
  for (const row of flagged) {
    if (!bySet.has(row.setId)) bySet.set(row.setId, new Set());
    bySet.get(row.setId)!.add(row.id);
  }

  let removed = 0;
  for (const [setId, problemIds] of bySet) {
    const doc = await col.findOne({ id: setId });
    if (!doc?.problems) continue;

    const problems = (doc.problems as GeneratedProblem[]).map((problem) => {
      if (!problemIds.has(problem.id)) return problem;
      if (dryRun) {
        console.log(`[dry-run set] ${setId} / ${problem.id} · ${problem.title}`);
        removed += 1;
        return problem;
      }
      removed += 1;
      console.log(`[removed set] ${setId} / ${problem.id} · ${problem.title}`);
      return {
        ...problem,
        visualizationData: null,
        solutionVisualizationData: null,
        visualizationMigrationStatus: "completed" as const,
        visualizationMigrationError: null,
      };
    });

    if (!dryRun) {
      await col.updateOne({ id: setId }, { $set: { problems } });
    }
  }
  return removed;
}

type LegacyFlaggedItem = {
  id: string;
  title: string;
  source?: "bank" | "set";
  setId?: string;
  promptVizType?: string | null;
  reasons?: string[];
  reason?: string;
  promptPreview?: string;
};

function loadFlaggedFromReport(): { bank: FlaggedBank[]; sets: FlaggedSetProblem[] } {
  const path = reportPath();
  if (!existsSync(path)) {
    throw new Error(`report not found: ${path}`);
  }
  const report = JSON.parse(readFileSync(path, "utf8")) as AuditReport & {
    items?: LegacyFlaggedItem[];
    samples?: LegacyFlaggedItem[];
  };

  if (report.bank?.flagged || report.sets?.flagged) {
    return {
      bank: report.bank?.flagged ?? [],
      sets: report.sets?.flagged ?? [],
    };
  }

  const legacy = report.items ?? report.samples ?? [];
  const bank: FlaggedBank[] = [];
  const sets: FlaggedSetProblem[] = [];
  for (const row of legacy) {
    const reason =
      row.reason ??
      (Array.isArray(row.reasons) ? row.reasons.join(" · ") : "불필요(레거시 감사)");
    if (row.source === "set" && row.setId) {
      sets.push({
        source: "set",
        setId: row.setId,
        id: row.id,
        title: row.title,
        reason,
        promptPreview: row.promptPreview ?? "",
      });
    } else {
      bank.push({
        source: "bank",
        id: row.id,
        title: row.title,
        reason,
        promptPreview: row.promptPreview ?? "",
      });
    }
  }
  return { bank, sets };
}

async function applyRemovals(
  db: NonNullable<Awaited<ReturnType<typeof getMongoDb>>>,
  bank: FlaggedBank[],
  sets: FlaggedSetProblem[],
  dryRun: boolean,
) {
  const bankRemoved = await removeFromBank(
    db.collection("problem_bank_items"),
    bank,
    dryRun,
  );
  const setsRemoved = await removeFromSets(
    db.collection("generated_problem_sets"),
    sets,
    dryRun,
  );
  return { bankRemoved, setsRemoved };
}

async function main() {
  const options = parseArgs(process.argv.slice(2));
  const db = await getMongoDb();
  if (!db) throw new Error("MongoDB not configured");

  if (options.applyFromReport) {
    const { bank, sets } = loadFlaggedFromReport();
    const { bankRemoved, setsRemoved } = await applyRemovals(db, bank, sets, options.dryRun);
    console.log(
      `\nfrom report: bank flagged=${bank.length} removed=${bankRemoved}, sets flagged=${sets.length} removed=${setsRemoved}`,
    );
    return;
  }

  const emptyBank = { withViz: 0, audited: 0, flagged: [] as FlaggedBank[] };
  const emptySets = { withViz: 0, audited: 0, flagged: [] as FlaggedSetProblem[] };

  const bank =
    options.target === "sets"
      ? emptyBank
      : await auditBank(db, options);
  const sets =
    options.target === "bank"
      ? emptySets
      : await auditSets(db, options);

  const report: AuditReport = {
    criterion:
      "문제 본문만 보고 풀이에 그래프·도형이 꼭 필요한지 판단 (그래프 이미지는 보지 않음)",
    target: options.target,
    bank,
    sets,
    flagged: bank.flagged.length + sets.flagged.length,
  };

  mkdirSync(join(process.cwd(), "artifacts"), { recursive: true });
  writeFileSync(reportPath(), JSON.stringify(report, null, 2), "utf8");

  console.log(
    `\nbank: withViz=${bank.withViz} audited=${bank.audited} unnecessary=${bank.flagged.length}`,
  );
  console.log(
    `sets: withViz=${sets.withViz} audited=${sets.audited} unnecessary=${sets.flagged.length}`,
  );
  console.log(`report → ${reportPath()}`);

  if (options.apply) {
    const { bankRemoved, setsRemoved } = await applyRemovals(
      db,
      bank.flagged,
      sets.flagged,
      options.dryRun,
    );
    console.log(
      `removed: bank=${bankRemoved} sets=${setsRemoved}${options.dryRun ? " (dry-run)" : ""}`,
    );
  } else if (report.flagged > 0) {
    console.log("제거: npm run audit:unnecessary-viz:apply");
  }
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
