"use client";

import { useEffect, useRef, useState } from "react";

import type { JsxGraphDiagram, JsxGraphBoardLike } from "@/lib/jsx-graph-spec";
import { applyDiagramToBoard } from "@/lib/jsx-graph-spec";

/** jsxgraph 패키지는 번들 형식에 따라 `default` 또는 네임스페이스 export를 씁니다 */
type JSXGraphApi = typeof import("jsxgraph");

function resolveJsxgraphNamespace(mod: JSXGraphApi): JSXGraphApi {
  const nested = (
    mod as unknown as {
      default?: JSXGraphApi;
    }
  ).default;
  return nested ?? mod;
}

export function JsxGraphRenderer({
  diagram,
}: {
  diagram: Exclude<JsxGraphDiagram, null>;
}) {
  const hostRef = useRef<HTMLDivElement | null>(null);
  const boardRef = useRef<unknown>(null);
  const [boxId] = useState(() =>
    typeof crypto !== "undefined"
      ? `jxbox-${crypto.randomUUID()}`
      : `jxbox-${Math.random().toString(36).slice(2)}`,
  );

  useEffect(() => {
    let cancelled = false;

    void (async () => {
      const loaded = await import("jsxgraph");
      const JXG = resolveJsxgraphNamespace(loaded);

      const pkg = JXG as {
        JSXGraph: {
          initBoard: (id: string, cfg: Record<string, unknown>) => unknown;
          freeBoard: (board: unknown) => void;
        };
      };

      if (cancelled || !diagram.diagramNeeded) return;

      const box = hostRef.current;
      if (!box) return;

      box.innerHTML = "";
      box.id = boxId;
      box.className = "jxgbox";

      const bb =
        diagram.board?.boundingbox && diagram.board.boundingbox.length === 4
          ? diagram.board.boundingbox
          : [-6, 12, 12, -6];

      const board = pkg.JSXGraph.initBoard(boxId, {
        boundingbox: bb,
        axis: diagram.board?.axis ?? true,
        keepaspectratio: diagram.board?.keepaspectratio ?? true,
        showCopyright: diagram.board?.showCopyright ?? false,
        showNavigation: diagram.board?.showNavigation ?? false,
        resize: { enabled: false },
        ...(diagram.board?.zoom ? { zoom: diagram.board.zoom } : {}),
      });

      boardRef.current = board;
      applyDiagramToBoard(board as JsxGraphBoardLike, diagram);
    })();

    return () => {
      cancelled = true;
      const b = boardRef.current;
      boardRef.current = null;
      if (!b) return;
      import("jsxgraph")
        .then((loaded) => {
          const JXG = resolveJsxgraphNamespace(loaded);
          (
            JXG as {
              JSXGraph?: { freeBoard: (board: unknown) => void };
            }
          ).JSXGraph?.freeBoard(b);
        })
        .catch(() => {});
    };
  }, [diagram, boxId]);

  if (!diagram.diagramNeeded) {
    return null;
  }

  return (
    <div className="mt-4 space-y-2">
      {diagram.captionKo ? (
        <p className="text-sm text-slate-300">{diagram.captionKo}</p>
      ) : null}
      {diagram.rationaleKo ? (
        <p className="text-xs text-slate-500">{diagram.rationaleKo}</p>
      ) : null}
      <div
        ref={hostRef}
        className="mx-auto w-full max-w-2xl overflow-hidden rounded-2xl border border-white/10 bg-white"
        style={{ height: 380, maxHeight: "60vh" }}
      />
    </div>
  );
}
