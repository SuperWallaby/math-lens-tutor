"use client";

import type { GeneratedProblem } from "@/lib/types";
import type { VisualizationData } from "@/lib/visualization-schema";
import {
  functionGraphDataSchema,
  resolveVisualizationPayload,
  visualizationDataToChartConfig,
  visualizationDataToJsxDiagram,
} from "@/lib/visualization-schema";

import { ChartRenderer } from "./ChartRenderer";
import { DesmosGraphRenderer } from "./DesmosGraphRenderer";
import { JsxGraphRenderer } from "./JsxGraphRenderer";

type LegacyProblem = Pick<
  GeneratedProblem,
  "visualizationData" | "solutionVisualizationData" | "chart" | "jsxGraph"
>;

export function VisualizationRenderer({
  problem,
  visualizationData,
  className = "mt-5",
}: {
  problem?: LegacyProblem;
  visualizationData?: VisualizationData | null;
  className?: string;
}) {
  const resolved = problem
    ? resolveVisualizationPayload(problem).prompt
    : visualizationData ?? null;

  if (!resolved) return null;

  const caption =
    typeof resolved.data.captionKo === "string"
      ? resolved.data.captionKo.trim()
      : "";

  if (resolved.engine === "desmos" || resolved.type === "function_graph") {
    const data = functionGraphDataSchema.parse(resolved.data);
    return (
      <div className={className}>
        {caption ? (
          <p className="mb-2 text-sm text-wy-text-sub">{caption}</p>
        ) : null}
        <DesmosGraphRenderer data={data} />
      </div>
    );
  }

  if (resolved.engine === "chartjs" || resolved.type === "chart") {
    const chart = visualizationDataToChartConfig(resolved);
    if (!chart) return null;
    return (
      <div className={`${className} rounded-wy-md bg-wy-surface p-4`}>
        {caption ? (
          <p className="mb-2 text-sm text-wy-text-sub">{caption}</p>
        ) : null}
        <ChartRenderer chart={chart as NonNullable<GeneratedProblem["chart"]>} />
      </div>
    );
  }

  const diagram = visualizationDataToJsxDiagram(resolved);
  if (!diagram?.diagramNeeded) return null;

  return (
    <div className={className}>
      <JsxGraphRenderer diagram={diagram} />
    </div>
  );
}

export function SolutionVisualizationRenderer({
  problem,
}: {
  problem: LegacyProblem & { explanation?: string };
}) {
  const solution = resolveVisualizationPayload(problem).solution;
  if (!solution) return null;

  return (
    <VisualizationRenderer
      visualizationData={solution}
      className="mt-4"
    />
  );
}
