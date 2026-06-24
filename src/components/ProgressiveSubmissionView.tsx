"use client";

import Image from "next/image";
import Link from "next/link";
import { MathMixedRich } from "@/components/MathMixedRich";
import { ProblemSetPrintPdfButton } from "@/components/ProblemSetPrintPdfButton";
import { Skeleton } from "@/components/Skeleton";
import {
  SkeletonLines,
  skeletonLinePresets,
} from "@/components/SkeletonLines";
import type { StreamingAnalyzeState } from "@/lib/analyze-stream-client";
import {
  meaningfulRecommendedFocus,
  meaningfulWeakConcepts,
} from "@/lib/types";

function hasVisionData(state: StreamingAnalyzeState) {
  const a = state.analysis;
  if (!a) return false;
  return (
    a.problemText.trim().length > 0 ||
    a.extractedStudentAnswer.trim().length > 0 ||
    a.solutionSteps.length > 0
  );
}

function hasTutorData(state: StreamingAnalyzeState) {
  const a = state.analysis;
  if (!a) return false;
  return a.inferredCorrectAnswer.trim().length > 0 && a.errorSummary.trim().length > 0;
}

export function ProgressiveSubmissionView({
  state,
  localPreviewUrl,
}: {
  state: StreamingAnalyzeState;
  localPreviewUrl?: string | null;
}) {
  const analysis = state.analysis;
  const problemSet = state.problemSet;
  const visionReady = hasVisionData(state);
  const tutorReady = hasTutorData(state);
  const similarReady = problemSet != null && problemSet.problems.length > 0;

  const weakShown = analysis
    ? meaningfulWeakConcepts(analysis.weakConcepts)
    : [];
  const focusShown = analysis
    ? meaningfulRecommendedFocus(analysis.recommendedFocus)
    : [];
  const showTrainingSection =
    tutorReady && (weakShown.length > 0 || focusShown.length > 0);

  const imageSrc = state.imageUrl ?? localPreviewUrl ?? null;

  return (
    <div className="grid gap-8 lg:grid-cols-[0.85fr_1.15fr]">
      <aside className="hidden space-y-6 lg:block">
        {similarReady && problemSet ? (
          <div className="space-y-3">
            <Link
              href={`/practice/${problemSet.id}`}
              className="block rounded-wy-md bg-wy-success px-6 py-4 text-center font-bold text-white hover:opacity-90"
            >
              유사 문제 5개 풀기
            </Link>
            <ProblemSetPrintPdfButton
              problemSet={problemSet}
              className="block w-full rounded-wy-md border border-wy-border-strong px-6 py-3 text-center text-sm font-semibold text-foreground hover:bg-wy-surface-muted"
            />
          </div>
        ) : (
          <div className="space-y-3">
            <SkeletonLines widths={skeletonLinePresets.button} gapClassName="gap-3" />
            <SkeletonLines widths={[72]} gapClassName="gap-3" />
          </div>
        )}
      </aside>

      <section className="space-y-6">
        <section className="rounded-[var(--wy-radius-md)] border border-wy-border bg-wy-surface p-6">
          <p className="text-sm text-wy-text-muted">제출한 풀이 사진</p>
          {imageSrc ? (
            <div className="mt-3 overflow-hidden rounded-wy-md bg-wy-surface-muted">
              <Image
                src={imageSrc}
                alt="업로드한 풀이 사진"
                width={800}
                height={600}
                unoptimized={imageSrc.startsWith("blob:")}
                className="max-h-[min(280px,40vh)] w-full object-contain"
              />
            </div>
          ) : (
            <div className="mt-3 space-y-2.5">
              <Skeleton className="skeleton-line w-[88%]" />
              <SkeletonLines widths={[76, 62]} gapClassName="gap-2" />
            </div>
          )}
        </section>

        <p className="text-sm font-medium text-wy-primary">{state.progressMessage}</p>

        <div className="rounded-[var(--wy-radius-md)] border border-wy-border bg-wy-surface p-6">
          <div className="flex flex-wrap items-center gap-3">
            {tutorReady && analysis ? (
              <span className="rounded-full bg-wy-surface-muted px-3 py-1 text-sm text-wy-text-sub">
                신뢰도 {Math.round(analysis.confidence * 100)}%
              </span>
            ) : (
              <Skeleton className="skeleton-line w-[28%]" />
            )}
            {visionReady && analysis?.imageQualityWarning ? (
              <span className="rounded-full bg-[var(--wy-warning-tint)] px-3 py-1 text-sm font-semibold text-foreground">
                이미지가 흐린 것 같아요
              </span>
            ) : null}
          </div>
          <h2 className="mt-5 text-2xl font-black">풀이 분석</h2>
          <div className="mt-4 rounded-wy-md bg-wy-surface-elevated p-4 leading-8 text-foreground">
            {visionReady && analysis ? (
              <MathMixedRich text={analysis.problemText} readableSolutionStep />
            ) : (
              <SkeletonLines widths={skeletonLinePresets.paragraph} />
            )}
          </div>
          <dl className="mt-5 grid gap-4 sm:grid-cols-2">
            <div className="rounded-wy-md bg-wy-surface-elevated p-4">
              <dt className="text-sm text-wy-text-muted">학생 답안</dt>
              <dd className="mt-2 font-bold">
                {visionReady && analysis ? (
                  <MathMixedRich
                    text={analysis.extractedStudentAnswer}
                    readableSolutionStep
                  />
                ) : (
                  <SkeletonLines
                    className="mt-2"
                    widths={skeletonLinePresets.short}
                    gapClassName="gap-2"
                  />
                )}
              </dd>
            </div>
            <div className="rounded-wy-md bg-wy-surface-elevated p-4">
              <dt className="text-sm text-wy-text-muted">추정 정답</dt>
              <dd className="mt-2 font-bold">
                {tutorReady && analysis ? (
                  <MathMixedRich
                    text={analysis.inferredCorrectAnswer}
                    softBreakExplanation
                    readableSolutionStep
                  />
                ) : (
                  <SkeletonLines
                    className="mt-2"
                    widths={[68, 52]}
                    gapClassName="gap-2"
                  />
                )}
              </dd>
            </div>
          </dl>
        </div>

        <div className="rounded-[var(--wy-radius-md)] border border-wy-border bg-wy-surface p-6">
          <h2 className="text-xl font-bold">정답 풀이</h2>
          {tutorReady &&
          analysis &&
          (analysis.referenceSolutionSteps?.length ?? 0) > 0 ? (
            <ol className="mt-5 list-decimal space-y-4 pl-5">
              {analysis.referenceSolutionSteps!.map((step, index) => (
                <li
                  key={`ref-${index}-${step.slice(0, 24)}`}
                  className="rounded-wy-md bg-[var(--wy-success-tint)] p-4 pl-4 leading-8 text-foreground marker:font-semibold"
                >
                  <MathMixedRich text={step} readableSolutionStep />
                </li>
              ))}
            </ol>
          ) : (
            <SkeletonLines
              className="mt-5"
              widths={skeletonLinePresets.answerSolution}
            />
          )}
        </div>

        <div className="rounded-[var(--wy-radius-md)] border border-wy-border bg-wy-surface p-6">
          <h2 className="text-xl font-bold">사진에서 읽은 학생 풀이·메모</h2>
          {visionReady && analysis && analysis.solutionSteps.length > 0 ? (
            <ol className="mt-5 list-decimal space-y-4 pl-5">
              {analysis.solutionSteps.map((step, index) => (
                <li
                  key={`${index}-${step.slice(0, 24)}`}
                  className="rounded-wy-md bg-wy-surface-elevated p-4 pl-4 leading-8 text-wy-text-sub marker:font-semibold"
                >
                  <MathMixedRich text={step} readableSolutionStep />
                </li>
              ))}
            </ol>
          ) : visionReady ? (
            <p className="mt-4 text-sm text-wy-text-muted">
              읽을 수 있는 손글씨 단계가 없습니다.
            </p>
          ) : (
            <SkeletonLines
              className="mt-5"
              widths={skeletonLinePresets.studentSteps}
            />
          )}
          {visionReady && (
            <div className="mt-6 border-t border-wy-border pt-5">
              <p className="text-sm font-medium text-wy-text-muted">
                {tutorReady ? "오답 진단" : "오답 진단 중…"}
              </p>
              <div className="mt-3 rounded-wy-md bg-[var(--wy-accent-tint)] p-4 leading-8 text-foreground">
                {tutorReady && analysis ? (
                  <MathMixedRich
                    text={analysis.errorSummary}
                    readableSolutionStep
                  />
                ) : (
                  <SkeletonLines
                    variant="error"
                    widths={skeletonLinePresets.error}
                    gapClassName="gap-2"
                  />
                )}
              </div>
            </div>
          )}
        </div>

        {showTrainingSection && analysis ? (
          <div className="rounded-[var(--wy-radius-md)] border border-wy-border bg-wy-surface p-6">
            <h2 className="text-xl font-bold">부족 개념과 추천 훈련</h2>
            {weakShown.length > 0 ? (
              <div className="mt-5 flex flex-wrap gap-2">
                {weakShown.map((concept) => (
                  <div
                    key={concept}
                    className="inline-flex max-w-full items-center rounded-full bg-[var(--wy-primary-tint)] px-3 py-1 text-sm text-wy-primary"
                  >
                    <MathMixedRich text={concept} />
                  </div>
                ))}
              </div>
            ) : null}
            {focusShown.length > 0 ? (
              <ul className="mt-5 space-y-3 text-sm leading-7 text-wy-text-sub">
                {focusShown.map((focus) => (
                  <li key={focus} className="rounded-wy-md bg-wy-surface-elevated p-4">
                    <MathMixedRich text={focus} />
                  </li>
                ))}
              </ul>
            ) : null}
          </div>
        ) : !tutorReady ? (
          <div className="rounded-[var(--wy-radius-md)] border border-wy-border bg-wy-surface p-6">
            <h2 className="text-xl font-bold">부족 개념과 추천 훈련</h2>
            <SkeletonLines
              className="mt-5"
              widths={skeletonLinePresets.training}
            />
          </div>
        ) : null}

        {similarReady && problemSet ? (
          <div className="space-y-3 lg:hidden">
            <Link
              href={`/practice/${problemSet.id}`}
              className="block rounded-wy-md bg-wy-success px-6 py-4 text-center font-bold text-white hover:opacity-90"
            >
              유사 문제 5개 풀기
            </Link>
            <ProblemSetPrintPdfButton
              problemSet={problemSet}
              className="block w-full rounded-wy-md border border-wy-border-strong px-6 py-3 text-center text-sm font-semibold text-foreground hover:bg-wy-surface-muted"
            />
          </div>
        ) : null}
      </section>
    </div>
  );
}
