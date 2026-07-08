import { z } from "zod";

import { sanitizeFunctionGraphData } from "./desmos-latex";
import type { JsxGraphDiagram } from "./jsx-graph-spec";

/** 문제·풀이 시각화 엔진 — bake 후 static */
export const visualizationEngineSchema = z.enum([
  "desmos",
  "jsxgraph",
  "chartjs",
  "static",
]);

/** bake 완료 후 data에 포함되는 정적 에셋 필드 */
export const staticAssetFieldsSchema = z.object({
  imageUrl: z.string().min(1),
  width: z.number().int().positive(),
  height: z.number().int().positive(),
  contentHash: z.string().min(1).optional(),
});

export type StaticAssetFields = z.infer<typeof staticAssetFieldsSchema>;

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
  imageUrl: z.string().min(1).optional(),
  width: z.number().int().positive().optional(),
  height: z.number().int().positive().optional(),
  contentHash: z.string().min(1).optional(),
});

function pickNonEmptyString(...values: unknown[]): string | undefined {
  for (const value of values) {
    if (typeof value === "string" && value.trim()) return value.trim();
  }
  return undefined;
}

/** AI가 expression 대신 latex/formula 등으로 줄 때 보정 */
export function coerceFunctionGraphData(
  raw: Record<string, unknown>,
): z.infer<typeof functionGraphDataSchema> | null {
  const expressions = Array.isArray(raw.expressions)
    ? raw.expressions
        .filter(
          (item): item is string =>
            typeof item === "string" && item.trim().length > 0,
        )
        .map((item) => item.trim())
    : [];

  let expression = pickNonEmptyString(
    raw.expression,
    raw.latex,
    raw.formula,
    raw.y,
    raw.function,
    expressions[0],
  );

  if (!expression) return null;

  if (!/^y\s*=/i.test(expression) && !expression.includes("=")) {
    expression = `y=${expression}`;
  }

  const payload: Record<string, unknown> = {
    expression,
    expressions: expressions.length > 0 ? expressions : undefined,
    captionKo: pickNonEmptyString(raw.captionKo),
  };

  if (
    Array.isArray(raw.xRange) &&
    raw.xRange.length === 2 &&
    typeof raw.xRange[0] === "number" &&
    typeof raw.xRange[1] === "number"
  ) {
    payload.xRange = raw.xRange;
  }
  if (
    Array.isArray(raw.yRange) &&
    raw.yRange.length === 2 &&
    typeof raw.yRange[0] === "number" &&
    typeof raw.yRange[1] === "number"
  ) {
    payload.yRange = raw.yRange;
  }

  const parsed = functionGraphDataSchema.safeParse(payload);
  return parsed.success ? parsed.data : null;
}

export function coerceGeometryData(
  raw: Record<string, unknown>,
): z.infer<typeof geometryDataSchema> | null {
  const points = raw.points;
  const elements = raw.elements;
  const hasPoints =
    points &&
    typeof points === "object" &&
    Object.keys(points as object).length > 0;
  const hasElements = Array.isArray(elements) && elements.length > 0;
  if (!hasPoints && !hasElements) return null;

  const parsed = geometryDataSchema.safeParse(raw);
  return parsed.success ? parsed.data : null;
}

export function coerceCoordinateData(
  raw: Record<string, unknown>,
): z.infer<typeof coordinateDataSchema> | null {
  const parsed = coordinateDataSchema.safeParse(raw);
  return parsed.success ? parsed.data : null;
}

const staticAssetOptionalFields = {
  imageUrl: z.string().min(1).optional(),
  width: z.number().int().positive().optional(),
  height: z.number().int().positive().optional(),
  contentHash: z.string().min(1).optional(),
} as const;

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
  ...staticAssetOptionalFields,
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
  ...staticAssetOptionalFields,
});

export const chartVisualizationDataSchema = z.object({
  type: z.enum(["bar", "line", "pie", "doughnut", "radar", "scatter"]),
  data: z.record(z.string(), z.unknown()),
  options: z.record(z.string(), z.unknown()).optional(),
  ...staticAssetOptionalFields,
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

function normalizeFunctionGraphExpressions(
  data: z.infer<typeof functionGraphDataSchema>,
): z.infer<typeof functionGraphDataSchema> {
  return sanitizeFunctionGraphData(data);
}

function parseStaticBakedVisualization(
  viz: NonNullable<z.infer<typeof visualizationDataSchema>>,
): VisualizationData {
  const data = viz.data ?? {};
  const asset = staticAssetFieldsSchema.safeParse(data);
  if (!asset.success) return null;

  switch (viz.type) {
    case "function_graph": {
      const coerced = coerceFunctionGraphData(data);
      if (!coerced) return null;
      return {
        type: "function_graph",
        engine: "static",
        data: { ...normalizeFunctionGraphExpressions(coerced), ...asset.data },
      };
    }
    case "geometry": {
      const legacy = data.legacyJsxGraph;
      if (legacy && typeof legacy === "object") {
        return {
          type: "geometry",
          engine: "static",
          data: {
            legacyJsxGraph: legacy,
            captionKo: pickNonEmptyString(data.captionKo),
            ...asset.data,
          },
        };
      }
      const coerced = coerceGeometryData(data);
      if (!coerced) return null;
      return { type: "geometry", engine: "static", data: { ...coerced, ...asset.data } };
    }
    case "coordinate": {
      const coerced = coerceCoordinateData(data);
      if (!coerced) return null;
      return { type: "coordinate", engine: "static", data: { ...coerced, ...asset.data } };
    }
    case "chart": {
      const parsed = chartVisualizationDataSchema.safeParse(data);
      if (!parsed.success) return null;
      return {
        type: "chart",
        engine: "static",
        data: { ...parsed.data, ...asset.data },
      };
    }
    default:
      return null;
  }
}

/** imageUrl이 있으면 bake 완료로 간주 */
export function visualizationHasBakedAsset(viz: VisualizationData): boolean {
  if (!viz) return false;
  const imageUrl = viz.data?.imageUrl;
  return typeof imageUrl === "string" && imageUrl.trim().length > 0;
}

/** viz 정의는 있으나 PNG가 아직 없음 */
export function visualizationAwaitingBake(
  viz: VisualizationData,
  status?: string | null,
): boolean {
  if (!viz || status === "failed") return false;
  if (visualizationHasBakedAsset(viz)) return false;
  return Boolean(viz.type);
}

/** viz가 있으나 정적 에셋이 없거나 engine이 static이 아니면 bake 필요 */
export function visualizationNeedsBaking(viz: VisualizationData): boolean {
  if (!viz) return false;
  if (!visualizationHasBakedAsset(viz)) return true;
  return viz.engine !== "static";
}

export function problemVisualizationPending(problem: {
  visualizationData?: VisualizationData | null;
  solutionVisualizationData?: VisualizationData | null;
  visualizationMigrationStatus?: string | null;
}): boolean {
  const status = problem.visualizationMigrationStatus;
  return (
    visualizationAwaitingBake(problem.visualizationData ?? null, status) ||
    visualizationAwaitingBake(problem.solutionVisualizationData ?? null, status)
  );
}

export function problemSetHasPendingVisualization(problemSet: {
  problems: Array<{
    visualizationData?: VisualizationData | null;
    solutionVisualizationData?: VisualizationData | null;
    visualizationMigrationStatus?: string | null;
  }>;
}): boolean {
  return problemSet.problems.some((problem) => problemVisualizationPending(problem));
}

/** 렌더러가 사용할 정규화 payload — legacy 필드와 통합 (실패 시 null, throw 안 함) */
export function validateVisualizationData(raw: VisualizationData): VisualizationData {
  if (!raw) return null;
  const base = visualizationDataSchema.safeParse(raw);
  if (!base.success) return null;

  const viz = base.data;
  if (!viz) return null;
  const data = viz.data ?? {};

  if (viz.engine === "static" || visualizationHasBakedAsset(viz)) {
    return parseStaticBakedVisualization(viz);
  }

  switch (viz.type) {
    case "function_graph": {
      const coerced = coerceFunctionGraphData(data);
      if (!coerced) return null;
      return {
        type: "function_graph",
        engine: "desmos",
        data: normalizeFunctionGraphExpressions(coerced),
      };
    }
    case "geometry": {
      const legacy = data.legacyJsxGraph;
      if (legacy && typeof legacy === "object") {
        return {
          type: "geometry",
          engine: "jsxgraph",
          data: {
            legacyJsxGraph: legacy,
            captionKo: pickNonEmptyString(data.captionKo),
          },
        };
      }
      const coerced = coerceGeometryData(data);
      if (!coerced) return null;
      return { type: "geometry", engine: "jsxgraph", data: coerced };
    }
    case "coordinate": {
      const coerced = coerceCoordinateData(data);
      if (!coerced) return null;
      return { type: "coordinate", engine: "jsxgraph", data: coerced };
    }
    case "chart": {
      const parsed = chartVisualizationDataSchema.safeParse(data);
      if (!parsed.success) return null;
      return {
        type: "chart",
        engine: "chartjs",
        data: parsed.data,
      };
    }
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
