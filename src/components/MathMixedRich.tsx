"use client";

import katex from "katex";
import { Fragment, useMemo } from "react";

import { augmentMathDelimiters } from "@/lib/augment-math-delimiters";
import { parseMathMixed } from "@/lib/parse-math-mixed";
import { softBreakAnswerExplanation } from "@/lib/soft-break-korean-math-text";

export function MathMixedRich({
  text,
  className,
  softBreakExplanation = false,
}: {
  text: string;
  className?: string;
  /** 한 줄로 이어진 "정답·오답 문장 + 풀이"에 설명 앞 줄바꿈을 삽입 (예: inferredCorrectAnswer) */
  softBreakExplanation?: boolean;
}) {
  const raw = text ?? "";
  const withBreaks = useMemo(
    () =>
      softBreakExplanation ? softBreakAnswerExplanation(raw) : raw.replace(/\r\n/g, "\n"),
    [raw, softBreakExplanation],
  );
  const normalized = useMemo(() => augmentMathDelimiters(withBreaks), [withBreaks]);
  const segments = useMemo(() => parseMathMixed(normalized), [normalized]);

  return (
    <div className={`math-mixed-root whitespace-pre-wrap wrap-break-word ${className ?? ""}`}>
      {segments.map((seg, i) => {
        if (seg.kind === "text") {
          const lines = seg.value.split("\n");
          return (
            <span key={`t-${i}`} className="whitespace-pre-wrap">
              {lines.map((line, li) => (
                <Fragment key={li}>
                  {li > 0 ? <br /> : null}
                  {line}
                </Fragment>
              ))}
            </span>
          );
        }

        try {
          const html = katex.renderToString(seg.latex, {
            displayMode: seg.kind === "block",
            throwOnError: false,
            strict: "ignore",
          });
          const Tag = seg.kind === "block" ? "div" : "span";
          return (
            <Tag
              key={`m-${i}`}
              className={
                seg.kind === "block"
                  ? "my-4 block overflow-x-auto text-center [&_.katex]:text-[1em]"
                  : "mx-px inline [&_.katex]:text-[1em]"
              }
              dangerouslySetInnerHTML={{ __html: html }}
            />
          );
        } catch {
          return (
            <code key={`err-${i}`} className="rounded bg-black/40 px-1 text-xs">
              {seg.kind === "block" ? `$$${seg.latex}$$` : `$${seg.latex}$`}
            </code>
          );
        }
      })}
    </div>
  );
}
