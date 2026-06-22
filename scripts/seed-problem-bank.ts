#!/usr/bin/env node
/**
 * 교육과정 단원별 문제 은행 시드 (Azure OpenAI 생성 → MongoDB).
 *
 *   npm run seed:problem-bank          # 전 단원 (기본 count=10, 부족분만)
 *   npm run seed:problem-bank:all      # 위와 동일 (별칭)
 *   npm run seed:problem-bank -- --band m1 --count 10
 *   npm run seed:problem-bank -- --unit m1-linear-equations --dry-run
 */
import { parseAnalyzeQualityMode } from "../src/lib/analyze-mode";
import { resolveAzureDeploymentName } from "../src/lib/azure";
import {
  GRADE_BAND_LABELS,
  listCurriculumUnits,
  type GradeBand,
} from "../src/lib/curriculum";
import { getActiveBankCountByUnit } from "../src/lib/problem-bank-store";
import { seedCurriculumUnitProblems } from "../src/lib/problem-bank";

type CliOptions = {
  band?: GradeBand;
  unitId?: string;
  count: number;
  dryRun: boolean;
  skipExisting: boolean;
  delayMs: number;
  qualityMode: ReturnType<typeof parseAnalyzeQualityMode>;
};

function parseArgs(argv: string[]): CliOptions {
  const opts: CliOptions = {
    count: 10,
    dryRun: false,
    skipExisting: true,
    delayMs: 1500,
    qualityMode: "balanced",
  };

  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i];
    if (arg === "--band" && argv[i + 1]) {
      opts.band = argv[i + 1] as GradeBand;
      i += 1;
    } else if (arg === "--unit" && argv[i + 1]) {
      opts.unitId = argv[i + 1];
      i += 1;
    } else if (arg === "--count" && argv[i + 1]) {
      opts.count = Math.min(10, Math.max(1, Number(argv[i + 1]) || 10));
      i += 1;
    } else if (arg === "--delay-ms" && argv[i + 1]) {
      opts.delayMs = Math.max(0, Number(argv[i + 1]) || 0);
      i += 1;
    } else if (arg === "--mode" && argv[i + 1]) {
      opts.qualityMode = parseAnalyzeQualityMode(argv[i + 1]);
      i += 1;
    } else if (arg === "--dry-run") {
      opts.dryRun = true;
    } else if (arg === "--force") {
      opts.skipExisting = false;
    }
  }

  return opts;
}

function sleep(ms: number) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function main() {
  const opts = parseArgs(process.argv.slice(2));
  const deploymentName = resolveAzureDeploymentName(opts.qualityMode);

  if (!deploymentName) {
    console.error(
      "Azure OpenAI 텍스트 배포가 없습니다. AZURE_OPENAI_DEPLOYMENT_BALANCED 등을 설정하세요.",
    );
    process.exit(1);
  }

  let targets = listCurriculumUnits(
    opts.band ? { gradeBand: opts.band } : undefined,
  );
  if (opts.unitId) {
    targets = targets.filter((row) => row.unit.id === opts.unitId);
  }

  if (targets.length === 0) {
    console.error("시드할 단원이 없습니다. --band / --unit 을 확인하세요.");
    process.exit(1);
  }

  console.log(
    `[seed] units=${targets.length} count=${opts.count} deployment=${deploymentName} dryRun=${opts.dryRun} skipExisting=${opts.skipExisting}`,
  );

  let seededUnits = 0;
  let seededProblems = 0;
  let skippedUnits = 0;

  for (const { unit, gradeBand } of targets) {
    const bandLabel = GRADE_BAND_LABELS[gradeBand];
    const existing = await getActiveBankCountByUnit(unit.id);

    if (opts.skipExisting && existing >= opts.count) {
      console.log(
        `[skip] ${bandLabel} ${unit.id} (${existing} items >= ${opts.count})`,
      );
      skippedUnits += 1;
      continue;
    }

    const need = opts.skipExisting ? Math.max(0, opts.count - existing) : opts.count;
    if (need === 0) {
      skippedUnits += 1;
      continue;
    }

    console.log(
      `[gen] ${bandLabel} ${unit.name} (${unit.id}) +${need} (existing ${existing})`,
    );

    if (opts.dryRun) {
      seededUnits += 1;
      seededProblems += need;
      continue;
    }

    try {
      const inserted = await seedCurriculumUnitProblems({
        unit,
        gradeBand,
        count: need,
        deploymentName,
        mode: opts.qualityMode,
      });
      seededUnits += 1;
      seededProblems += inserted;
      console.log(`[ok] ${unit.id} inserted=${inserted}`);
    } catch (error) {
      console.error(
        `[fail] ${unit.id}`,
        error instanceof Error ? error.message : error,
      );
    }

    if (opts.delayMs > 0) {
      await sleep(opts.delayMs);
    }
  }

  console.log(
    `[done] unitsSeeded=${seededUnits} problems=${seededProblems} skipped=${skippedUnits}`,
  );
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
