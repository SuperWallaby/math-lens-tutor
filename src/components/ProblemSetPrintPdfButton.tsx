"use client";

import { useRef } from "react";
import { useReactToPrint } from "react-to-print";
import { MathMixedRich } from "@/components/MathMixedRich";
import type { GeneratedProblem, GeneratedProblemSet } from "@/lib/types";

function documentTitleFromSet(set: GeneratedProblemSet) {
  const raw = set.title.replace(/[/\\?%*:|"<>]/g, " ").trim();
  return raw.slice(0, 80) || `유사문제_${set.id}`;
}

function ProblemPrintBlock({
  problem,
  index,
}: {
  problem: GeneratedProblem;
  index: number;
}) {
  const hasFigure =
    problem.chart != null ||
    (problem.jsxGraph?.diagramNeeded === true);

  return (
    <section className="break-inside-avoid border-b border-black/20 pb-4">
      <p className="text-sm text-black/70">
        문제 {index + 1} · {problem.difficulty}
        {problem.conceptTags.length > 0
          ? ` · ${problem.conceptTags.join(", ")}`
          : ""}
      </p>
      <h3 className="mt-2 text-base font-bold text-black">{problem.title}</h3>
      <div className="math-mixed-root mt-2 text-sm leading-relaxed text-black">
        <MathMixedRich text={problem.prompt} />
      </div>
      {hasFigure ? (
        <p className="mt-2 text-xs text-black/60">
          (그래프·도형은 웹/앱 화면에서 확인하세요.)
        </p>
      ) : null}
      {problem.type === "multiple_choice" && problem.choices ? (
        <ol className="mt-3 list-decimal space-y-1 pl-5 text-sm text-black">
          {problem.choices.map((c) => (
            <li key={c.id} className="math-mixed-root">
              <MathMixedRich text={`${c.id}. ${c.label}`} />
            </li>
          ))}
        </ol>
      ) : null}
    </section>
  );
}

export function ProblemSetPrintPdfButton({
  problemSet,
  className,
}: {
  problemSet: GeneratedProblemSet;
  className?: string;
}) {
  const printRef = useRef<HTMLDivElement>(null);
  const handlePrint = useReactToPrint({
    contentRef: printRef,
    documentTitle: documentTitleFromSet(problemSet),
    pageStyle: `@page { size: A4; margin: 14mm; }`,
  });

  return (
    <>
      <button
        type="button"
        onClick={() => void handlePrint()}
        className={
          className ??
          "rounded-2xl border border-white/15 px-5 py-2.5 text-sm font-semibold text-slate-100 hover:bg-white/10"
        }
      >
        유사문제 PDF로 받기
      </button>
      <div
        ref={printRef}
        className="pointer-events-none fixed top-0 left-[-9999px] w-[190mm] bg-white p-6 text-black print:static print:left-auto print:w-auto"
        aria-hidden
      >
        <header className="border-b border-black/30 pb-4">
          <p className="text-xs text-black/60">유사 문제 세트 · {problemSet.id}</p>
          <div className="math-mixed-root mt-2 text-xl font-black text-black">
            <MathMixedRich text={problemSet.title} />
          </div>
          <div className="math-mixed-root mt-2 text-sm leading-relaxed text-black/80">
            <MathMixedRich text={problemSet.learningGoal} />
          </div>
        </header>
        <div className="mt-4 space-y-6">
          {problemSet.problems.map((p, i) => (
            <ProblemPrintBlock key={p.id} problem={p} index={i} />
          ))}
        </div>
        <p className="mt-8 text-xs text-black/50">
          브라우저 인쇄 창에서 &quot;PDF로 저장&quot;을 선택하면 파일로 받을 수 있습니다.
        </p>
      </div>
    </>
  );
}
