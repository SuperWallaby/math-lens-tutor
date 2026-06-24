"use client";

import { useState } from "react";
import { MathMixedRich } from "./MathMixedRich";
import {
  SolutionVisualizationRenderer,
  VisualizationRenderer,
} from "./VisualizationRenderer";
import { ProblemSetPrintPdfButton } from "./ProblemSetPrintPdfButton";
import type { GeneratedProblemSet, ProblemAttempt } from "@/lib/types";
import { formatChoiceDisplayLabel } from "@/lib/choice-label-format";
import { formatDifficultyLabel } from "@/lib/problem-labels";

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
          className="rounded-[var(--wy-radius-md)] border border-wy-border bg-wy-surface p-6"
        >
          <div className="flex flex-wrap items-center gap-3">
            <span className="rounded-full bg-[var(--wy-primary-tint)] px-3 py-1 text-sm text-wy-primary">
              문제 {index + 1}
            </span>
            <span className="rounded-full bg-wy-surface-muted px-3 py-1 text-xs text-wy-text-sub">
              {formatDifficultyLabel(problem.difficulty)}
            </span>
            {problem.conceptTags.map((tag) => (
              <span
                key={tag}
                className="rounded-full bg-wy-surface-muted px-3 py-1 text-xs text-wy-text-sub"
              >
                {tag}
              </span>
            ))}
          </div>
          <h2 className="mt-4 text-xl font-bold">{problem.title}</h2>
          <MathMixedRich
            text={problem.prompt}
            className="mt-3 leading-8 text-foreground"
          />
          <VisualizationRenderer problem={problem} />

          {problem.type === "multiple_choice" && problem.choices ? (
            <div className="mt-5 grid gap-3 sm:grid-cols-2">
              {problem.choices.map((choice) => (
                <label
                  key={choice.id}
                  className="flex cursor-pointer items-center gap-3 rounded-wy-md border border-wy-border bg-wy-surface-elevated p-4 text-sm hover:border-wy-primary"
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
                    text={formatChoiceDisplayLabel(choice.id, choice.label)}
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
              className="mt-5 min-h-32 w-full rounded-wy-md border border-wy-border bg-wy-surface-elevated p-4 text-sm text-foreground outline-none focus:border-wy-primary"
            />
          )}

          <button
            onClick={() => submitAnswer(problem.id)}
            disabled={!answers[problem.id] || submittingId === problem.id}
            className="mt-5 rounded-wy-md bg-wy-success px-5 py-3 font-semibold text-white transition hover:opacity-90 disabled:cursor-not-allowed disabled:opacity-60"
          >
            {submittingId === problem.id ? "채점 중..." : "답안 제출"}
          </button>

          {feedback[problem.id] ? (
            <div
              className={`mt-5 rounded-wy-md p-4 text-sm leading-6 ${
                feedback[problem.id].isCorrect
                  ? "bg-[var(--wy-success-tint)] text-foreground"
                  : "bg-[var(--wy-accent-tint)] text-foreground"
              }`}
            >
              <MathMixedRich text={feedback[problem.id].feedback} />
              {problem.explanation ? (
                <div className="mt-4 border-t border-wy-border pt-4">
                  <p className="mb-2 text-xs font-semibold text-wy-text-sub">
                    풀이 설명
                  </p>
                  <MathMixedRich text={problem.explanation} />
                  <SolutionVisualizationRenderer problem={problem} />
                </div>
              ) : null}
            </div>
          ) : null}
        </section>
      ))}
    </div>
  );
}
