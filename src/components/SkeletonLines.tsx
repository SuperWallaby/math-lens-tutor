import { Skeleton, type SkeletonVariant } from "@/components/Skeleton";

/** 콘텐츠 영역별 텍스트 라인 스켈레톤 너비(%) */
export const skeletonLinePresets = {
  /** 정답 풀이·짧은 설명 */
  answerSolution: [92, 68, 84],
  /** 풀이과정·불릿 단계 */
  studentSteps: [52, 84, 68, 92, 56],
  /** 일반 문단 */
  paragraph: [92, 68, 84, 52],
  /** 학생/정답 한 줄 */
  short: [72, 48],
  /** 오답 진단 */
  error: [88, 62],
  /** 부족 개념·훈련 */
  training: [42, 88, 68],
  /** CTA 버튼 */
  button: [88],
} as const;

export function SkeletonLines({
  widths,
  variant = "default",
  className = "",
  gapClassName = "gap-2.5",
}: {
  widths: readonly number[];
  variant?: SkeletonVariant;
  className?: string;
  gapClassName?: string;
}) {
  return (
    <div
      className={`flex w-full flex-col ${gapClassName} ${className}`}
      aria-hidden
    >
      {widths.map((w, i) => (
        <Skeleton
          key={`${w}-${i}`}
          variant={variant}
          className="skeleton-line"
          style={{ width: `${w}%` }}
        />
      ))}
    </div>
  );
}
