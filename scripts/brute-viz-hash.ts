#!/usr/bin/env node
import { visualizationContentHash } from "../src/lib/visualization-baker";
import { validateVisualizationData } from "../src/lib/visualization-schema";
import { normalizeDesmosLatex } from "../src/lib/desmos-latex";

const TARGET = process.argv[2] ?? "7ce01cace7d41916";

function hashExpr(expression: string, xRange?: [number, number], yRange?: [number, number]) {
  const viz = validateVisualizationData({
    type: "function_graph",
    engine: "desmos",
    data: {
      expression: normalizeDesmosLatex(expression),
      ...(xRange ? { xRange } : {}),
      ...(yRange ? { yRange } : {}),
    },
  });
  if (!viz) return null;
  return visualizationContentHash(viz);
}

const xRange: [number, number] = [-3, 4];
const yRange: [number, number] = [-1.5, 1.5];

const candidates = [
  "y=x^2",
  "y=x^2-4",
  "y=2x+1",
  "y=-x+2",
  "y=sin(x)",
  "y=sin(3x)",
  "y=cos(x)",
  "y=tan(x)",
  "y=1/x",
  "y=sqrt(x)",
  "y=log(x)",
  "y=log_2(x)",
  "y=|x|",
  "y=abs(x)",
  "x^2+y^2=1",
  "x^2/4+y^2/1=1",
  "y=x^2-2x-3",
  "y=(x-1)(x+3)",
  "y=\\frac{1}{x}",
  "y=\\sin\\left(x\\right)",
];

for (const expr of candidates) {
  const h = hashExpr(expr, xRange, yRange);
  if (h === TARGET) {
    console.log("MATCH", expr);
    process.exit(0);
  }
}

console.log("no match in candidates for", TARGET);
