#!/usr/bin/env node
/** Heuristic: empty Desmos bakes are mostly white/gray grid with very low blue curve signal. */
import { readdirSync, readFileSync } from "fs";
import { join } from "path";

import { pngLikelyEmptyGraph } from "../src/lib/viz-png-empty";

const vizDir = join(process.cwd(), "public/viz");

async function main() {
  const files = readdirSync(vizDir).filter((f) => f.endsWith(".png"));
  const empty: string[] = [];
  for (const file of files) {
    const png = readFileSync(join(vizDir, file));
    if (await pngLikelyEmptyGraph(png)) {
      empty.push(file.replace(/\.png$/, ""));
    }
  }
  console.log(`scanned ${files.length}, likely empty: ${empty.length}`);
  console.log(empty.slice(0, 40).join("\n"));
  if (empty.length > 40) console.log(`... +${empty.length - 40} more`);
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
