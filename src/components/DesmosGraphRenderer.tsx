"use client";

import { useEffect, useRef } from "react";

import type { z } from "zod";

import type { functionGraphDataSchema } from "@/lib/visualization-schema";

type FunctionGraphData = z.infer<typeof functionGraphDataSchema>;

type DesmosCalc = {
  setExpression: (spec: { id: string; latex: string }) => void;
  setMathBounds: (bounds: {
    left: number;
    right: number;
    bottom: number;
    top: number;
  }) => void;
  destroy: () => void;
};

declare global {
  interface Window {
    Desmos?: {
      GraphingCalculator: (
        element: HTMLElement,
        options?: Record<string, unknown>,
      ) => DesmosCalc;
    };
  }
}

const DESMOS_API_KEY =
  process.env.NEXT_PUBLIC_DESMOS_API_KEY?.trim() ||
  "dcb31709b452b1f69fc8a5890484ff01";

function loadDesmosScript(): Promise<void> {
  if (typeof window === "undefined") return Promise.resolve();
  if (window.Desmos) return Promise.resolve();

  return new Promise((resolve, reject) => {
    const existing = document.querySelector<HTMLScriptElement>(
      'script[data-desmos-api="1"]',
    );
    if (existing) {
      existing.addEventListener("load", () => resolve(), { once: true });
      existing.addEventListener("error", () => reject(new Error("Desmos load failed")), {
        once: true,
      });
      return;
    }

    const script = document.createElement("script");
    script.src = `https://www.desmos.com/api/v1.9/calculator.js?apiKey=${DESMOS_API_KEY}`;
    script.async = true;
    script.dataset.desmosApi = "1";
    script.onload = () => resolve();
    script.onerror = () => reject(new Error("Desmos script failed"));
    document.head.appendChild(script);
  });
}

export function DesmosGraphRenderer({ data }: { data: FunctionGraphData }) {
  const hostRef = useRef<HTMLDivElement | null>(null);

  useEffect(() => {
    let calc: DesmosCalc | null = null;
    let cancelled = false;

    void (async () => {
      await loadDesmosScript();
      if (cancelled || !hostRef.current || !window.Desmos) return;

      calc = window.Desmos.GraphingCalculator(hostRef.current, {
        expressions: false,
        settingsMenu: false,
        zoomButtons: true,
      });

      const expressions = data.expressions?.length
        ? data.expressions
        : [data.expression];

      expressions.forEach((latex, index) => {
        calc?.setExpression({ id: `e${index}`, latex });
      });

      if (data.xRange && data.yRange) {
        calc.setMathBounds({
          left: data.xRange[0],
          right: data.xRange[1],
          bottom: data.yRange[0],
          top: data.yRange[1],
        });
      }
    })();

    return () => {
      cancelled = true;
      calc?.destroy();
    };
  }, [data]);

  return (
    <div
      ref={hostRef}
      className="mt-4 h-[22rem] w-full overflow-hidden rounded-wy-md border border-wy-border bg-white"
    />
  );
}
