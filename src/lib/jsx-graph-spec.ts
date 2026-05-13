import { z } from "zod";

/**
 * AI 생성 → 클라에서 JSXGraph 로 해석합니다.
 * elType 은 JSXGraph 의 board.create(kind, …) 와 같은 이름입니다.
 */

const jsxBoardOptionsSchema = z
  .object({
    boundingbox: z.array(z.number()).length(4).optional(),
    axis: z.boolean().optional(),
    keepaspectratio: z.boolean().optional(),
    showCopyright: z.boolean().optional(),
    showNavigation: z.boolean().optional(),
    zoom: z.record(z.string(), z.unknown()).optional(),
  })
  .optional();

const jsxElementSpecSchema = z.object({
  id: z.string().optional(),
  elType: z.string(),
  coord: z.tuple([z.number(), z.number()]).optional(),
  parents: z.array(z.unknown()).optional(),
  attrs: z.record(z.string(), z.unknown()).optional(),
});

export const jsxGraphDiagramSchema = z
  .object({
    diagramNeeded: z.boolean().optional().default(false),
    rationaleKo: z
      .string()
      .optional()
      .describe("한국어: 왜 필요한지(짧게). 필요 없음이면 생략"),
    captionKo: z.string().optional().describe("그림 설명 한 줄"),
    board: jsxBoardOptionsSchema,
    elements: z.array(jsxElementSpecSchema).optional().default([]),
  })
  .nullable();

export type JsxGraphDiagram = z.infer<typeof jsxGraphDiagramSchema>;

const ALLOWED_ELTYPES = new Set([
  "point",
  "segment",
  "line",
  "polygon",
  "circle",
  "arc",
  "sector",
  "angle",
  "text",
  "ticks",
  "grid",
  "midpoint",
  "perpendicular",
  "perpendicularsegment",
  "bisector",
  "glider",
]);

export type JsxGraphBoardLike = {
  create: (
    kind: string,
    parents: unknown[],
    attrs?: Record<string, unknown>,
  ) => unknown;
};

/**
 * 브라우저 + JS 환경(Flutter WebView 포함) 에서 같은 로직 공유 가능하도록
 * 순수 문자열 블록으로도 내보낼 수 있게 작성 (아래 문자열 참고).
 */
export function applyDiagramToBoard(
  board: JsxGraphBoardLike,
  diagram: Exclude<JsxGraphDiagram, null>,
) {
  type Registry = Record<string, unknown>;
  const registry: Registry = {};

  const resolveParent = (p: unknown): unknown => {
    if (
      typeof p === "string" &&
      registry[p]
    ) {
      return registry[p];
    }
    if (
      Array.isArray(p) &&
      p.length === 2 &&
      typeof p[0] === "number" &&
      typeof p[1] === "number"
    ) {
      return p;
    }
    if (typeof p === "number") return p;
    return p;
  };

  for (const el of diagram.elements ?? []) {
    const type = String(el.elType ?? "").trim();
    if (!ALLOWED_ELTYPES.has(type)) continue;

    let parents: unknown[] = el.parents ?? [];
    if (type === "point" && el.coord && parents.length === 0) {
      parents = [el.coord];
    }
    const resolvedParents = parents.map(resolveParent);

    const obj = board.create(type, resolvedParents, el.attrs ?? {});
    const id = String(el.id ?? "").trim();
    if (id) registry[id] = obj;
  }
}
