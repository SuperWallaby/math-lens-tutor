import { z } from "zod";

import type { JsxGraphDiagram } from "./jsx-graph-spec";

/** 문제·풀이 시각화 엔진 — 추후 geogebra 등 확장 가능 */
export const visualizationEngineSchema = z.enum(["desmos", "jsxgraph", "chartjs"]);

export const visualizationTypeSchema = z.enum([
  "function_graph",
  "geometry",
  "coordinate",
  "chart",
]);

export const functionGraphDataSchema = z.object({
  expression: z.string().min(1),
  expressions: z.array(z.string()).optional(),
  xRange: z.tuple([z.number(), z.number()]).optional(),
  yRange: z.tuple([z.number(), z.number()]).optional(),
  captionKo: z.string().optional(),
});

export const geometryDataSchema = z.object({
  shape: z
    .enum(["triangle", "rectangle", "circle", "polygon", "custom"])
    .optional()
    .default("custom"),
  points: z.record(z.string(), z.tuple([z.number(), z.number()])).optional(),
  elements: z.array(z.record(z.string(), z.unknown())).optional(),
  showLabels: z.boolean().optional().default(true),
  captionKo: z.string().optional(),
  /** JSXGraph board 옵션 — 미지정 시 points 기준 자동 */
  board: z
    .object({
      boundingbox: z.tuple([z.number(), z.number(), z.number(), z.number()]).optional(),
      axis: z.boolean().optional(),
    })
    .optional(),
});

export const coordinateDataSchema = z.object({
  captionKo: z.string().optional(),
  board: z
    .object({
      boundingbox: z.tuple([z.number(), z.number(), z.number(), z.number()]),
      axis: z.boolean().optional(),
    })
    .optional(),
  elements: z.array(z.record(z.string(), z.unknown())).default([]),
});

export const chartVisualizationDataSchema = z.object({
  type: z.enum(["bar", "line", "pie", "doughnut", "radar", "scatter"]),
  data: z.record(z.string(), z.unknown()),
  options: z.record(z.string(), z.unknown()).optional(),
});

export const visualizationDataSchema = z
  .object({
    type: visualizationTypeSchema,
    engine: visualizationEngineSchema,
    data: z.record(z.string(), z.unknown()),
  })
  .nullable();

export type VisualizationData = z.infer<typeof visualizationDataSchema>;
export type VisualizationMigrationStatus =
  | "pending"
  | "processing"
  | "completed"
  | "failed";

export const visualizationMigrationStatusSchema = z.enum([
  "pending",
  "processing",
  "completed",
  "failed",
]);

function defaultBoundingBox(
  points: Record<string, [number, number]>,
): [number, number, number, number] {
  const coords = Object.values(points);
  if (coords.length === 0) return [-6, 12, 12, -6];
  const xs = coords.map((p) => p[0]);
  const ys = coords.map((p) => p[1]);
  const pad = 2;
  return [
    Math.min(...xs) - pad,
    Math.max(...ys) + pad,
    Math.max(...xs) + pad,
    Math.min(...ys) - pad,
  ];
}

/** geometry.data → JSXGraph diagram (기존 jsxGraph 렌더러 재사용) */
export function geometryDataToJsxDiagram(
  data: z.infer<typeof geometryDataSchema>,
): JsxGraphDiagram {
  const points = data.points ?? {};
  const elements: NonNullable<JsxGraphDiagram>["elements"] = [];
  const ids = Object.keys(points);

  for (const [id, coord] of Object.entries(points)) {
    elements.push({
      elType: "point",
      id,
      coord,
      attrs: {
        name: data.showLabels ? id : "",
        fixed: true,
        size: 3,
      },
    });
  }

  if (data.shape === "triangle" && ids.length >= 3) {
    elements.push({
      elType: "polygon",
      parents: ids.slice(0, 3),
      attrs: { fillColor: "#e8f4fc", borders: { strokeColor: "#2563eb" } },
    });
  } else if (data.shape === "polygon" && ids.length >= 3) {
    elements.push({
      elType: "polygon",
      parents: ids,
      attrs: { fillColor: "#e8f4fc", borders: { strokeColor: "#2563eb" } },
    });
  }

  for (const el of data.elements ?? []) {
    elements.push(el as NonNullable<JsxGraphDiagram>["elements"][number]);
  }

  return {
    diagramNeeded: true,
    captionKo: data.captionKo,
    board: {
      boundingbox:
        data.board?.boundingbox ?? defaultBoundingBox(points),
      axis: data.board?.axis ?? true,
      keepaspectratio: true,
    },
    elements,
  };
}

/** coordinate.data → JSXGraph diagram */
export function coordinateDataToJsxDiagram(
  data: z.infer<typeof coordinateDataSchema>,
): JsxGraphDiagram {
  return {
    diagramNeeded: true,
    captionKo: data.captionKo,
    board: {
      boundingbox: data.board?.boundingbox ?? [-6, 12, 12, -6],
      axis: data.board?.axis ?? true,
      keepaspectratio: true,
    },
    elements: (data.elements ?? []) as NonNullable<JsxGraphDiagram>["elements"],
  };
}

export function legacyJsxGraphToVisualization(
  jsxGraph: JsxGraphDiagram | null | undefined,
): VisualizationData {
  if (!jsxGraph?.diagramNeeded) return null;
  return {
    type: "geometry",
    engine: "jsxgraph",
    data: { legacyJsxGraph: jsxGraph },
  };
}

export function legacyChartToVisualization(
  chart: { type: string; data: unknown; options?: unknown } | null | undefined,
): VisualizationData {
  if (!chart) return null;
  return {
    type: "chart",
    engine: "chartjs",
    data: {
      type: chart.type,
      data: chart.data,
      options: chart.options,
    },
  };
}

/** 렌더러가 사용할 정규화 payload — legacy 필드와 통합 */
export function validateVisualizationData(raw: VisualizationData): VisualizationData {
  if (!raw) return null;
  const base = visualizationDataSchema.parse(raw);
  if (!base) return null;

  switch (base.type) {
    case "function_graph":
      functionGraphDataSchema.parse(base.data);
      if (base.engine !== "desmos") {
        return { ...base, engine: "desmos" };
      }
      return base;
    case "geometry":
      geometryDataSchema.parse(base.data);
      if (base.engine !== "jsxgraph") {
        return { ...base, engine: "jsxgraph" };
      }
      return base;
    case "coordinate":
      coordinateDataSchema.parse(base.data);
      if (base.engine !== "jsxgraph") {
        return { ...base, engine: "jsxgraph" };
      }
      return base;
    case "chart":
      chartVisualizationDataSchema.parse(base.data);
      if (base.engine !== "chartjs") {
        return { ...base, engine: "chartjs" };
      }
      return base;
    default:
      return null;
  }
}

export function parseVisualizationData(raw: unknown): VisualizationData {
  const parsed = visualizationDataSchema.safeParse(raw);
  return parsed.success ? parsed.data : null;
}

export function resolveVisualizationPayload(problem: {
  visualizationData?: VisualizationData | null;
  solutionVisualizationData?: VisualizationData | null;
  chart?: { type: string; data: unknown; options?: unknown } | null;
  jsxGraph?: JsxGraphDiagram | null;
}): {
  prompt: VisualizationData;
  solution: VisualizationData;
} {
  const prompt =
    parseVisualizationData(problem.visualizationData) ??
    legacyChartToVisualization(problem.chart) ??
    legacyJsxGraphToVisualization(problem.jsxGraph);

  const solution = parseVisualizationData(problem.solutionVisualizationData);

  return { prompt, solution };
}

export function normalizeProblemVisualization<
  T extends {
    chart?: { type: string; data: unknown; options?: unknown } | null;
    jsxGraph?: JsxGraphDiagram | null;
    visualizationData?: VisualizationData | null;
    solutionVisualizationData?: VisualizationData | null;
  },
>(problem: T): T {
  let visualizationData = validateVisualizationData(
    parseVisualizationData(problem.visualizationData),
  );
  if (!visualizationData) {
    visualizationData =
      legacyChartToVisualization(problem.chart) ??
      legacyJsxGraphToVisualization(problem.jsxGraph);
  }

  const solutionVisualizationData = validateVisualizationData(
    parseVisualizationData(problem.solutionVisualizationData),
  );

  return {
    ...problem,
    visualizationData,
    solutionVisualizationData,
  };
}

/** Web/Flutter JSXGraph 렌더러용 diagram 변환 */
export function visualizationDataToJsxDiagram(
  viz: Exclude<VisualizationData, null>,
): JsxGraphDiagram | null {
  const legacy = viz.data.legacyJsxGraph;
  if (legacy && typeof legacy === "object") {
    return legacy as JsxGraphDiagram;
  }

  if (viz.type === "geometry") {
    return geometryDataToJsxDiagram(
      geometryDataSchema.parse(viz.data),
    );
  }

  if (viz.type === "coordinate") {
    return coordinateDataToJsxDiagram(
      coordinateDataSchema.parse(viz.data),
    );
  }

  return null;
}

export function visualizationDataToChartConfig(
  viz: Exclude<VisualizationData, null>,
): { type: string; data: unknown; options?: unknown } | null {
  if (viz.type !== "chart" && viz.engine !== "chartjs") return null;
  const parsed = chartVisualizationDataSchema.parse(viz.data);
  return {
    type: parsed.type,
    data: parsed.data,
    options: parsed.options,
  };
}
