#!/usr/bin/env node
/**
 * Bake a single visualization JSON to PNG (local dev / smoke test).
 *
 *   npm run bake:viz -- --expression "y=sin(3x)" --x-min -6.28 --x-max 6.28 --y-min -1.2 --y-max 1.2
 *   npm run bake:viz -- --dry-run
 */
import { writeFileSync } from "fs";
import { join } from "path";

import {
  bakeVisualizationData,
} from "../src/lib/visualization-bake";
import {
  initVisualizationBaker,
  shutdownVisualizationBaker,
} from "../src/lib/visualization-baker";
import type { VisualizationData } from "../src/lib/visualization-schema";

function parseArgs(argv: string[]) {
  const expressionFlag = argv.indexOf("--expression");
  const outFlag = argv.indexOf("--out");
  return {
    dryRun: argv.includes("--dry-run"),
    expression:
      expressionFlag >= 0 ? argv[expressionFlag + 1] : "y=sin(3x)",
    xMin: Number(argv[argv.indexOf("--x-min") + 1] ?? -6.28),
    xMax: Number(argv[argv.indexOf("--x-max") + 1] ?? 6.28),
    yMin: Number(argv[argv.indexOf("--y-min") + 1] ?? -1.2),
    yMax: Number(argv[argv.indexOf("--y-max") + 1] ?? 1.2),
    out: outFlag >= 0 ? argv[outFlag + 1] : undefined,
  };
}

async function main() {
  const options = parseArgs(process.argv.slice(2));
  const viz: VisualizationData = {
    type: "function_graph",
    engine: "desmos",
    data: {
      expression: options.expression,
      xRange: [options.xMin, options.xMax],
      yRange: [options.yMin, options.yMax],
    },
  };

  if (options.dryRun) {
    console.log(JSON.stringify(viz, null, 2));
    return;
  }

  await initVisualizationBaker();
  try {
    const baked = await bakeVisualizationData(viz);
    if (!baked) {
      throw new Error("bake returned null");
    }
    console.log(JSON.stringify(baked, null, 2));
    if (options.out) {
      const imageUrl = baked.data.imageUrl;
      if (typeof imageUrl === "string" && imageUrl.startsWith("/viz/")) {
        const hash = imageUrl.replace("/viz/", "").replace(".png", "");
        const src = join(process.cwd(), "public", "viz", `${hash}.png`);
        writeFileSync(options.out, await import("fs/promises").then((m) => m.readFile(src)));
        console.log(`copied to ${options.out}`);
      }
    }
  } finally {
    await shutdownVisualizationBaker();
  }
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
