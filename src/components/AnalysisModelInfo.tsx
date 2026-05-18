import type { SubmissionModelMeta } from "@/lib/types";

export function AnalysisModelInfo({ meta }: { meta: SubmissionModelMeta }) {
  return (
    <div className="rounded-2xl border border-white/10 bg-slate-900/80 px-4 py-3 text-xs leading-relaxed text-slate-300">
      <p className="font-semibold text-slate-200">사용 모델</p>
      <ul className="mt-2 space-y-1 font-mono text-slate-400">
        <li>비전: {meta.visionModel}</li>
        <li>텍스트·유사문제: {meta.textModel}</li>
        <li>모드: {meta.qualityMode}</li>
        {meta.isSample ? <li>샘플 분석 데이터</li> : null}
      </ul>
    </div>
  );
}
