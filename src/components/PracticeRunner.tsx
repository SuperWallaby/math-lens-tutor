"use client";

import { useState } from "react";
import { ChartRenderer } from "./ChartRenderer";
import { JsxGraphRenderer } from "./JsxGraphRenderer";
import { MathMixedRich } from "./MathMixedRich";
import { ProblemSetPrintPdfButton } from "./ProblemSetPrintPdfButton";
import type { GeneratedProblemSet, ProblemAttempt } from "@/lib/types";

type Answers = Record<string, string>;
type Feedback = Record<string, ProblemAttempt>;

export function PracticeRunner({ problemSet }: { problemSet: GeneratedProblemSet }) {
  const [answers, setAnswers] = useState<Answers>({});
  const [feedback, setFeedback] = useState<Feedback>({});
  const [submittingId, setSubmittingId] = useState<string | null>(null);

  async function submitAnswer(problemId: string) {
    const answer = answers[problemId];
    if (!answer) {
      return;
    }

    setSubmittingId(problemId);
    const response = await fetch("/api/attempts", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        setId: problemSet.id,
        problemId,
        answer,
      }),
    });
    const payload = (await response.json()) as ProblemAttempt;
    setSubmittingId(null);

    if (response.ok) {
      setFeedback((current) => ({ ...current, [problemId]: payload }));
    }
  }

  return (
    <div className="space-y-6">
      <div className="no-print flex flex-wrap gap-3">
        <ProblemSetPrintPdfButton problemSet={problemSet} />
      </div>
      {problemSet.problems.map((problem, index) => (
        <section
          key={problem.id}
          className="rounded-3xl border border-white/10 bg-white/10 p-6"
        >
          <div className="flex flex-wrap items-center gap-3">
            <span className="rounded-full bg-blue-500/20 px-3 py-1 text-sm text-blue-200">
              문제 {index + 1}
            </span>
            <span className="rounded-full bg-slate-800 px-3 py-1 text-xs text-slate-300">
              {problem.difficulty}
            </span>
            {problem.conceptTags.map((tag) => (
              <span
                key={tag}
                className="rounded-full bg-white/10 px-3 py-1 text-xs text-slate-300"
              >
                {tag}
              </span>
            ))}
          </div>
          <h2 className="mt-4 text-xl font-bold">{problem.title}</h2>
          <MathMixedRich
            text={problem.prompt}
            className="mt-3 leading-8 text-slate-200"
          />
          {problem.chart ? (
            <div className="mt-5 rounded-2xl bg-white p-4">
              <ChartRenderer chart={problem.chart} />
            </div>
          ) : null}

          {problem.jsxGraph?.diagramNeeded ? (
            <JsxGraphRenderer diagram={problem.jsxGraph} />
          ) : null}

          {problem.type === "multiple_choice" && problem.choices ? (
            <div className="mt-5 grid gap-3 sm:grid-cols-2">
              {problem.choices.map((choice) => (
                <label
                  key={choice.id}
                  className="flex cursor-pointer items-center gap-3 rounded-2xl border border-white/10 bg-slate-900 p-4 text-sm hover:border-blue-400"
                >
                  <input
                    type="radio"
                    name={problem.id}
                    value={choice.id}
                    checked={answers[problem.id] === choice.id}
                    onChange={() =>
                      setAnswers((current) => ({
                        ...current,
                        [problem.id]: choice.id,
                      }))
                    }
                  />
                  <MathMixedRich
                    text={`${choice.id}. ${choice.label}`}
                    className="inline leading-7"
                  />
                </label>
              ))}
            </div>
          ) : (
            <textarea
              value={answers[problem.id] ?? ""}
              onChange={(event) =>
                setAnswers((current) => ({
                  ...current,
                  [problem.id]: event.target.value,
                }))
              }
              placeholder="풀이 또는 답안을 직접 작성하세요."
              className="mt-5 min-h-32 w-full rounded-2xl border border-white/10 bg-slate-900 p-4 text-sm text-white outline-none focus:border-blue-400"
            />
          )}

          <button
            onClick={() => submitAnswer(problem.id)}
            disabled={!answers[problem.id] || submittingId === problem.id}
            className="mt-5 rounded-2xl bg-emerald-500 px-5 py-3 font-semibold text-white transition hover:bg-emerald-400 disabled:cursor-not-allowed disabled:opacity-60"
          >
            {submittingId === problem.id ? "채점 중..." : "답안 제출"}
          </button>

          {feedback[problem.id] ? (
            <div
              className={`mt-5 rounded-2xl p-4 text-sm leading-6 ${
                feedback[problem.id].isCorrect
                  ? "bg-emerald-500/15 text-emerald-100"
                  : "bg-red-500/15 text-red-100"
              }`}
            >
              <MathMixedRich text={feedback[problem.id].feedback} />
            </div>
          ) : null}
        </section>
      ))}
    </div>
  );
}
