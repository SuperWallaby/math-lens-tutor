import type { SubmissionModelMeta } from "@/lib/types";

export function AnalysisModelInfo({ meta }: { meta: SubmissionModelMeta }) {
  return (
    <div className="rounded-wy-md border border-wy-border bg-wy-surface-elevated px-4 py-3 text-xs leading-relaxed text-wy-text-sub">
      <p className="font-semibold text-foreground">사용 모델</p>
      <ul className="mt-2 space-y-1 font-mono text-wy-text-muted">
        <li>비전: {meta.visionModel}</li>
        <li>텍스트·유사문제: {meta.textModel}</li>
        <li>모드: {meta.qualityMode}</li>
        {meta.isSample ? <li>샘플 분석 데이터</li> : null}
      </ul>
    </div>
  );
}
