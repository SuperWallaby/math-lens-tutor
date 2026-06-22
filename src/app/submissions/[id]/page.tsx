import Image from "next/image";
import Link from "next/link";
import { notFound } from "next/navigation";
import { AnalysisModelInfo } from "@/components/AnalysisModelInfo";
import { AppShell } from "@/components/AppShell";
import { MathMixedRich } from "@/components/MathMixedRich";
import { ProblemSetPrintPdfButton } from "@/components/ProblemSetPrintPdfButton";
import {
  meaningfulRecommendedFocus,
  meaningfulWeakConcepts,
} from "@/lib/types";
import { getProblemSetBySubmission, getSubmission } from "@/lib/store";

export default async function SubmissionPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;
  const submission = await getSubmission(id);

  if (!submission) {
    notFound();
  }

  const problemSet = await getProblemSetBySubmission(submission.id);
  const { analysis } = submission;
  const modelMeta = submission.modelMeta ?? submission.devMeta;

  const weakShown = meaningfulWeakConcepts(analysis.weakConcepts);
  const focusShown = meaningfulRecommendedFocus(analysis.recommendedFocus);
  const showTrainingSection =
    weakShown.length > 0 || focusShown.length > 0;

  return (
    <AppShell>
      <div className="grid gap-8 lg:grid-cols-[0.85fr_1.15fr]">
        <aside className="hidden space-y-6 lg:block">
          {problemSet ? (
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
          ) : null}
        </aside>

        <section className="space-y-6">
          <section className="rounded-[var(--wy-radius-md)] border border-wy-border bg-wy-surface p-6">
            <p className="text-sm text-wy-text-muted">제출한 풀이 사진</p>
            {submission.imageUrl ? (
              <Image
                src={submission.imageUrl}
                alt="업로드한 풀이 사진"
                width={800}
                height={600}
                className="mt-3 max-h-[min(280px,40vh)] w-full rounded-wy-md object-contain"
              />
            ) : (
              <p className="mt-3 text-sm text-wy-text-muted">이미지를 불러올 수 없습니다.</p>
            )}
          </section>

          <div className="rounded-[var(--wy-radius-md)] border border-wy-border bg-wy-surface p-6">
            <div className="flex flex-wrap items-center gap-3">
              <span className="rounded-full bg-wy-surface-muted px-3 py-1 text-sm text-wy-text-sub">
                신뢰도 {Math.round(analysis.confidence * 100)}%
              </span>
              {analysis.imageQualityWarning ? (
                <span className="rounded-full bg-[var(--wy-warning-tint)] px-3 py-1 text-sm font-semibold text-foreground">
                  이미지가 흐린 것 같아요
                </span>
              ) : null}
            </div>
            {modelMeta ? (
              <div className="mt-4">
                <AnalysisModelInfo meta={modelMeta} />
              </div>
            ) : null}
            <h2 className="mt-5 text-2xl font-black">풀이 분석</h2>
            <div className="mt-4 rounded-wy-md bg-wy-surface-elevated p-4 leading-8 text-foreground">
              <MathMixedRich text={analysis.problemText} readableSolutionStep />
            </div>
            <dl className="mt-5 grid gap-4 sm:grid-cols-2">
              <div className="rounded-wy-md bg-wy-surface-elevated p-4">
                <dt className="text-sm text-wy-text-muted">학생 답안</dt>
                <dd className="mt-2 font-bold">
                  <MathMixedRich
                    text={analysis.extractedStudentAnswer}
                    readableSolutionStep
                  />
                </dd>
              </div>
              <div className="rounded-wy-md bg-wy-surface-elevated p-4">
                <dt className="text-sm text-wy-text-muted">추정 정답</dt>
                <dd className="mt-2 font-bold">
                  <MathMixedRich
                    text={analysis.inferredCorrectAnswer}
                    softBreakExplanation
                    readableSolutionStep
                  />
                </dd>
              </div>
            </dl>
          </div>

          {(analysis.referenceSolutionSteps?.length ?? 0) > 0 ? (
            <div className="rounded-[var(--wy-radius-md)] border border-wy-border bg-wy-surface p-6">
              <h2 className="text-xl font-bold">정답 풀이</h2>
              <p className="mt-2 text-sm text-wy-text-muted">
                문제 지문만 보고 푼 모범 풀이입니다.
              </p>
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
            </div>
          ) : null}

          <div className="rounded-[var(--wy-radius-md)] border border-wy-border bg-wy-surface p-6">
            <h2 className="text-xl font-bold">사진에서 읽은 학생 풀이·메모</h2>
            <p className="mt-2 text-sm text-wy-text-muted">
              손글씨 OCR입니다. 소수 나열 등은 정답 풀이가 아닐 수 있습니다.
            </p>
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
            <div className="mt-5 rounded-wy-md bg-[var(--wy-accent-tint)] p-4 leading-8 text-foreground">
              <MathMixedRich text={analysis.errorSummary} readableSolutionStep />
            </div>
          </div>

          {showTrainingSection ? (
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
          ) : null}

          {problemSet ? (
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
    </AppShell>
  );
}
