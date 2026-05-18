import { z } from "zod";

import { jsxGraphDiagramSchema } from "./jsx-graph-spec";
import {
  coerceLlmString,
  llmConfidenceField,
  llmStringField,
} from "./zod-llm";

/** 과거 빈 배열 대신 들어가던 플레이스홀더 — UI에서 “내용 없음”으로 취급 */
export const WEAK_CONCEPTS_PLACEHOLDER_LEGACY =
  "사진만으로는 부족한 개념을 특정하기 어렵습니다.";
export const RECOMMENDED_FOCUS_PLACEHOLDER_LEGACY =
  "우선 동일 유형 문제를 조금 더 풀며 풀이 과정을 적는 연습을 권합니다.";

export function meaningfulWeakConcepts(items: readonly string[]): string[] {
  return items
    .map((s) => s.trim())
    .filter((s) => s.length > 0 && s !== WEAK_CONCEPTS_PLACEHOLDER_LEGACY);
}

export function meaningfulRecommendedFocus(items: readonly string[]): string[] {
  return items
    .map((s) => s.trim())
    .filter((s) => s.length > 0 && s !== RECOMMENDED_FOCUS_PLACEHOLDER_LEGACY);
}

export const SOLUTION_STEPS_EXTRACTION_FALLBACK =
  "이미지에서 풀이 단계를 명확히 구분하기 어렵습니다.";

/** LLM 이 빈 배열을 줄 때가 있어 파싱 단계에서 최소 1개 보장 */
function stringArrayWithFallback(fallback: string) {
  return z
    .array(z.string())
    .transform((arr) => {
      const cleaned = arr.map((s) => s.trim()).filter(Boolean);
      return cleaned.length > 0 ? cleaned : [fallback];
    });
}

/** 비전이 추출한 풀이 과정 배열 → 분석용 (빈 경우 단일 안내 문장) */
export function normalizeVisionSolutionSteps(steps: readonly string[]): string[] {
  const cleaned = steps.map((s) => s.trim()).filter(Boolean);
  return cleaned.length > 0 ? cleaned : [SOLUTION_STEPS_EXTRACTION_FALLBACK];
}

export const chartConfigSchema = z
  .object({
    type: z.enum(["bar", "line", "pie", "doughnut", "radar", "scatter"]),
    data: z.record(z.string(), z.unknown()),
    options: z.record(z.string(), z.unknown()).optional(),
  })
  .nullable();

/**
 * 풀이 사진 비전 단계 출력: 문제·손글씀 풀이(단계)·최종 답 형태 + 이미지 품질 지표.
 * `solutionSteps` 는 사진에 보이는 학생 풀이를 줄·단계 순으로 OCR 한 것(튜터링 재서술 금지).
 */
export const visionSolutionExtractionSchema = z.object({
  problemText: llmStringField(),
  extractedStudentAnswer: llmStringField(),
  /** 사진에 보이는 풀이 과정 한 줄씩(위→아래·왼→오 순; KaTeX 가능) */
  solutionSteps: z
    .array(z.string())
    .transform((arr) => arr.map((s) => s.trim()).filter(Boolean)),
  /** 1에 가까울수록 선명·읽기 쉬움, 낮으면 흐림·노출 부족 등 */
  imageClarityScore: z.number().min(0).max(1),
  /** 추출에 대한 확신도(가독성·완결성 포함) */
  extractionConfidence: z.number().min(0).max(1),
});

/** 인쇄된 problemText 만으로 정답·모범 풀이 (학생 손글씨 OCR 과 분리) */
export const problemSolveResultSchema = z.object({
  inferredCorrectAnswer: llmStringField(),
  referenceSolutionSteps: z
    .array(z.string())
    .transform((arr) => {
      const cleaned = arr.map((s) => s.trim()).filter(Boolean);
      return cleaned.length > 0
        ? cleaned
        : ["단계별 풀이를 생성하지 못했습니다."];
    }),
});

export type ProblemSolveResult = z.infer<typeof problemSolveResultSchema>;

/** 텍스트 튜터 2단계: 비전이 준 problem/solutionSteps 외 나머지만 채움 */
export const tutorExpansionFromVisionSchema = z.object({
  problemText: llmStringField(),
  extractedStudentAnswer: llmStringField(),
  inferredCorrectAnswer: llmStringField(),
  confidence: llmConfidenceField(),
  errorSummary: llmStringField(),
  weakConcepts: z
    .array(z.string())
    .transform((arr) =>
      arr.map((s) => s.trim()).filter(Boolean),
    ),
  recommendedFocus: z
    .array(z.string())
    .transform((arr) =>
      arr.map((s) => s.trim()).filter(Boolean),
    ),
});

export type TutorExpansionFromVision = z.infer<
  typeof tutorExpansionFromVisionSchema
>;

/** 비전 OCR 후 정답 풀이 + 진단을 한 번에 (서버 타임아웃 절감) */
export const tutorSolveAndExpandFromVisionSchema =
  tutorExpansionFromVisionSchema.extend({
    referenceSolutionSteps: problemSolveResultSchema.shape
      .referenceSolutionSteps,
  });

export type TutorSolveAndExpandFromVision = z.infer<
  typeof tutorSolveAndExpandFromVisionSchema
>;

export type VisionSolutionExtraction = z.infer<
  typeof visionSolutionExtractionSchema
>;

export const solutionAnalysisSchema = z.object({
  problemText: llmStringField(),
  extractedStudentAnswer: llmStringField(),
  inferredCorrectAnswer: llmStringField(),
  confidence: llmConfidenceField(),
  /** 사진에서 OCR 한 학생 손글씨·메모 */
  solutionSteps: stringArrayWithFallback(SOLUTION_STEPS_EXTRACTION_FALLBACK),
  /** 모델이 문제만 보고 푼 모범 풀이 단계 */
  referenceSolutionSteps: z
    .array(z.string())
    .optional()
    .default([]),
  errorSummary: llmStringField(),
  weakConcepts: z
    .array(z.unknown())
    .transform((arr) =>
      arr.map((s) => coerceLlmString(s)).filter(Boolean),
    ),
  recommendedFocus: z
    .array(z.unknown())
    .transform((arr) =>
      arr.map((s) => coerceLlmString(s)).filter(Boolean),
    ),
  imageQualityWarning: z.boolean().optional().default(false),
  visionImageClarityScore: z.number().min(0).max(1).optional(),
  visionExtractionConfidence: z.number().min(0).max(1).optional(),
});

export const generatedProblemSchema = z.preprocess((raw) => {
  if (!raw || typeof raw !== "object") return raw;
  const o = raw as Record<string, unknown>;
  if (!("jsxGraph" in o)) {
    return { ...o, jsxGraph: null };
  }
  return o;
}, z.object({
  id: z.string(),
  type: z.enum(["multiple_choice", "free_response"]),
  title: z.string(),
  prompt: z.string(),
  choices: z
    .array(
      z.object({
        id: z.string(),
        label: z.string(),
      }),
    )
    .optional(),
  correctAnswer: z.string(),
  explanation: z.string(),
  difficulty: z.enum(["easy", "medium", "hard"]),
  conceptTags: z.array(z.string()).min(1),
  chart: chartConfigSchema,
  /** 필요할 때만: 좌표평면 도형 (JSXGraph). 불필요하면 null */
  jsxGraph: jsxGraphDiagramSchema,
}));

export const generatedProblemSetSchema = z.object({
  id: z.string(),
  submissionId: z.string(),
  title: z.string(),
  learningGoal: z.string(),
  problems: z.array(generatedProblemSchema).length(5),
});

/** 한 번의 비전 호출로 분석 + 유사 문제 세트를 함께 받을 때 */
export const unifiedAnalyzeProblemSetSchema = z.object({
  analysis: solutionAnalysisSchema,
  problemSet: generatedProblemSetSchema,
});

export type SolutionAnalysis = z.infer<typeof solutionAnalysisSchema>;
export type GeneratedProblem = z.infer<typeof generatedProblemSchema>;
export type GeneratedProblemSet = z.infer<typeof generatedProblemSetSchema>;
export type { JsxGraphDiagram } from "./jsx-graph-spec";
export type UnifiedAnalyzeProblemSet = z.infer<
  typeof unifiedAnalyzeProblemSetSchema
>;

/** 분석 요청에 사용된 모델(결과 화면 표시·디버깅) */
export type SubmissionModelMeta = {
  visionModel: string;
  textModel: string;
  qualityMode: string;
  isSample: boolean;
};

/** @deprecated SubmissionModelMeta 사용 */
export type SubmissionDevMeta = SubmissionModelMeta;

export type SolutionSubmission = {
  id: string;
  userId: string;
  imageUrl: string | null;
  imageName: string;
  createdAt: string;
  analysis: SolutionAnalysis;
  modelMeta?: SubmissionModelMeta;
  /** @deprecated modelMeta */
  devMeta?: SubmissionModelMeta;
};

export type ProblemAttempt = {
  id: string;
  userId: string;
  setId: string;
  problemId: string;
  answer: string;
  isCorrect: boolean;
  feedback: string;
  createdAt: string;
};

export type ApiErrorLog = {
  id: string;
  route: string;
  method: string;
  userId: string;
  message: string;
  name?: string;
  stack?: string;
  url?: string;
  userAgent?: string;
  createdAt: string;
};

export type LearningInsight = {
  levelLabel: string;
  masteryScore: number;
  totalAttempts: number;
  accuracy: number;
  weakConcepts: { concept: string; misses: number }[];
  recentFeedback: string[];
  trendChart: NonNullable<z.infer<typeof chartConfigSchema>>;
};
