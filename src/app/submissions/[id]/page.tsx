import Image from "next/image";
import Link from "next/link";
import { notFound } from "next/navigation";
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

  const weakShown = meaningfulWeakConcepts(analysis.weakConcepts);
  const focusShown = meaningfulRecommendedFocus(analysis.recommendedFocus);
  const showTrainingSection =
    weakShown.length > 0 || focusShown.length > 0;

  return (
    <AppShell>
      <div className="grid gap-8 lg:grid-cols-[0.85fr_1.15fr]">
        <aside className="space-y-6">
          <section className="rounded-3xl border border-white/10 bg-white/10 p-6">
            <p className="text-sm text-slate-400">업로드 파일</p>
            <h1 className="mt-2 text-2xl font-black">{submission.imageName}</h1>
            {submission.imageUrl ? (
              <Image
                src={submission.imageUrl}
                alt="업로드한 풀이 사진"
                width={800}
                height={600}
                className="mt-5 rounded-2xl object-cover"
              />
            ) : (
              <div className="mt-5 rounded-2xl bg-slate-900 p-6 text-sm leading-6 text-slate-400">
                MongoDB가 연결되지 않아 데모 모드로 분석 결과만
                표시합니다.
              </div>
            )}
          </section>
          {problemSet ? (
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
          ) : null}
        </aside>

        <section className="space-y-6">
          <div className="rounded-3xl border border-white/10 bg-white/10 p-6">
            <div className="flex flex-wrap items-center gap-3">
              <span className="rounded-full bg-white/10 px-3 py-1 text-sm text-slate-300">
                신뢰도 {Math.round(analysis.confidence * 100)}%
              </span>
              {analysis.imageQualityWarning ? (
                <span className="rounded-full bg-amber-500/25 px-3 py-1 text-sm font-semibold text-amber-100">
                  이미지가 흐린 것 같아요
                </span>
              ) : null}
            </div>
            <h2 className="mt-5 text-2xl font-black">AI 풀이 분석</h2>
            <div className="mt-4 rounded-2xl bg-slate-900 p-4 leading-8 text-slate-200">
              <MathMixedRich text={analysis.problemText} />
            </div>
            <dl className="mt-5 grid gap-4 sm:grid-cols-2">
              <div className="rounded-2xl bg-slate-900 p-4">
                <dt className="text-sm text-slate-400">학생 답안</dt>
                <dd className="mt-2 font-bold">
                  <MathMixedRich text={analysis.extractedStudentAnswer} />
                </dd>
              </div>
              <div className="rounded-2xl bg-slate-900 p-4">
                <dt className="text-sm text-slate-400">추정 정답</dt>
                <dd className="mt-2 font-bold">
                  <MathMixedRich
                    text={analysis.inferredCorrectAnswer}
                    softBreakExplanation
                  />
                </dd>
              </div>
            </dl>
          </div>

          <div className="rounded-3xl border border-white/10 bg-white/10 p-6">
            <h2 className="text-xl font-bold">풀이과정</h2>
            <ol className="mt-5 list-decimal space-y-3 pl-5">
              {analysis.solutionSteps.map((step, index) => (
                <li
                  key={`${index}-${step.slice(0, 24)}`}
                  className="rounded-2xl bg-slate-900 p-4 pl-4 leading-7 text-slate-300 marker:font-semibold"
                >
                  <MathMixedRich text={step} />
                </li>
              ))}
            </ol>
            <div className="mt-5 rounded-2xl bg-red-500/15 p-4 leading-7 text-red-100">
              <MathMixedRich text={analysis.errorSummary} />
            </div>
          </div>

          {showTrainingSection ? (
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
          ) : null}
        </section>
      </div>
    </AppShell>
  );
}
