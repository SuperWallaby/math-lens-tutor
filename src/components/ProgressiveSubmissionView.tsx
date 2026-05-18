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
              className="block rounded-2xl bg-emerald-500 px-6 py-4 text-center font-bold text-white hover:bg-emerald-400"
            >
              유사 문제 5개 풀기
            </Link>
            <ProblemSetPrintPdfButton
              problemSet={problemSet}
              className="block w-full rounded-2xl border border-white/15 px-6 py-3 text-center text-sm font-semibold text-slate-100 hover:bg-white/10"
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
        <section className="rounded-3xl border border-white/10 bg-white/10 p-6">
          <p className="text-sm text-slate-400">제출한 풀이 사진</p>
          <h2 className="mt-1 text-lg font-bold text-slate-100">
            {state.imageName || "풀이 사진"}
          </h2>
          {imageSrc ? (
            <Image
              src={imageSrc}
              alt="업로드한 풀이 사진"
              width={800}
              height={600}
              unoptimized={imageSrc.startsWith("blob:")}
              className="mt-3 max-h-[min(280px,40vh)] w-full rounded-2xl object-contain"
            />
          ) : (
            <div className="mt-3 space-y-2.5">
              <Skeleton className="skeleton-line w-[88%]" />
              <SkeletonLines widths={[76, 62]} gapClassName="gap-2" />
            </div>
          )}
        </section>

        <p className="text-sm font-medium text-blue-200">{state.progressMessage}</p>

        <div className="rounded-3xl border border-white/10 bg-white/10 p-6">
          <div className="flex flex-wrap items-center gap-3">
            {tutorReady && analysis ? (
              <span className="rounded-full bg-white/10 px-3 py-1 text-sm text-slate-300">
                신뢰도 {Math.round(analysis.confidence * 100)}%
              </span>
            ) : (
              <Skeleton className="skeleton-line w-[28%]" />
            )}
            {visionReady && analysis?.imageQualityWarning ? (
              <span className="rounded-full bg-amber-500/25 px-3 py-1 text-sm font-semibold text-amber-100">
                이미지가 흐린 것 같아요
              </span>
            ) : null}
          </div>
          <h2 className="mt-5 text-2xl font-black">풀이 분석</h2>
          <div className="mt-4 rounded-2xl bg-slate-900 p-4 leading-8 text-slate-200">
            {visionReady && analysis ? (
              <MathMixedRich text={analysis.problemText} readableSolutionStep />
            ) : (
              <SkeletonLines widths={skeletonLinePresets.paragraph} />
            )}
          </div>
          <dl className="mt-5 grid gap-4 sm:grid-cols-2">
            <div className="rounded-2xl bg-slate-900 p-4">
              <dt className="text-sm text-slate-400">학생 답안</dt>
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
            <div className="rounded-2xl bg-slate-900 p-4">
              <dt className="text-sm text-slate-400">추정 정답</dt>
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

        <div className="rounded-3xl border border-white/10 bg-white/10 p-6">
          <h2 className="text-xl font-bold">정답 풀이</h2>
          {tutorReady &&
          analysis &&
          (analysis.referenceSolutionSteps?.length ?? 0) > 0 ? (
            <ol className="mt-5 list-decimal space-y-4 pl-5">
              {analysis.referenceSolutionSteps!.map((step, index) => (
                <li
                  key={`ref-${index}-${step.slice(0, 24)}`}
                  className="rounded-2xl bg-emerald-500/10 p-4 pl-4 leading-8 text-slate-200 marker:font-semibold"
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

        <div className="rounded-3xl border border-white/10 bg-white/10 p-6">
          <h2 className="text-xl font-bold">사진에서 읽은 학생 풀이·메모</h2>
          {visionReady && analysis && analysis.solutionSteps.length > 0 ? (
            <ol className="mt-5 list-decimal space-y-4 pl-5">
              {analysis.solutionSteps.map((step, index) => (
                <li
                  key={`${index}-${step.slice(0, 24)}`}
                  className="rounded-2xl bg-slate-900 p-4 pl-4 leading-8 text-slate-300 marker:font-semibold"
                >
                  <MathMixedRich text={step} readableSolutionStep />
                </li>
              ))}
            </ol>
          ) : visionReady ? (
            <p className="mt-4 text-sm text-slate-400">
              읽을 수 있는 손글씨 단계가 없습니다.
            </p>
          ) : (
            <SkeletonLines
              className="mt-5"
              widths={skeletonLinePresets.studentSteps}
            />
          )}
          {visionReady && (
            <div className="mt-6 border-t border-white/10 pt-5">
              <p className="text-sm font-medium text-slate-400">
                {tutorReady ? "오답 진단" : "오답 진단 중…"}
              </p>
              <div className="mt-3 rounded-2xl bg-red-500/10 p-4 leading-8 text-red-100">
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
          <div className="rounded-3xl border border-white/10 bg-white/10 p-6">
            <h2 className="text-xl font-bold">부족 개념과 추천 훈련</h2>
            {weakShown.length > 0 ? (
              <div className="mt-5 flex flex-wrap gap-2">
                {weakShown.map((concept) => (
                  <div
                    key={concept}
                    className="inline-flex max-w-full items-center rounded-full bg-blue-500/20 px-3 py-1 text-sm text-blue-100"
                  >
                    <MathMixedRich text={concept} />
                  </div>
                ))}
              </div>
            ) : null}
            {focusShown.length > 0 ? (
              <ul className="mt-5 space-y-3 text-sm leading-7 text-slate-300">
                {focusShown.map((focus) => (
                  <li key={focus} className="rounded-2xl bg-slate-900 p-4">
                    <MathMixedRich text={focus} />
                  </li>
                ))}
              </ul>
            ) : null}
          </div>
        ) : !tutorReady ? (
          <div className="rounded-3xl border border-white/10 bg-white/10 p-6">
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
              className="block rounded-2xl bg-emerald-500 px-6 py-4 text-center font-bold text-white hover:bg-emerald-400"
            >
              유사 문제 5개 풀기
            </Link>
            <ProblemSetPrintPdfButton
              problemSet={problemSet}
              className="block w-full rounded-2xl border border-white/15 px-6 py-3 text-center text-sm font-semibold text-slate-100 hover:bg-white/10"
            />
          </div>
        ) : null}
      </section>
    </div>
  );
}
