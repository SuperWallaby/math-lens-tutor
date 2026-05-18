import type { SubmissionDevMeta } from "@/lib/types";

export function AnalysisDevModelInfo({ meta }: { meta: SubmissionDevMeta }) {
  return (
    <div className="rounded-2xl border border-dashed border-violet-500/35 bg-violet-500/10 px-4 py-3 text-xs leading-relaxed text-violet-100">
      <p className="font-semibold text-violet-200">개발 — 사용 모델</p>
      <ul className="mt-2 space-y-1 font-mono text-violet-100/90">
        <li>비전: {meta.visionModel}</li>
        <li>텍스트·유사문제: {meta.textModel}</li>
        <li>모드: {meta.qualityMode}</li>
        {meta.isSample ? <li>샘플 분석 데이터</li> : null}
      </ul>
    </div>
  );
}
