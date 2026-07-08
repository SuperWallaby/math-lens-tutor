import { z } from "zod";

import { jsxGraphDiagramSchema } from "./jsx-graph-spec";
import {
  visualizationDataSchema,
  visualizationMigrationStatusSchema,
  type VisualizationData,
  type VisualizationMigrationStatus,
} from "./visualization-schema";
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
//** 1212 */

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
  /** 목록·피드 카드용 짧은 한글 제목 (수식 없음) */
  listTitle: llmStringField().optional(),
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
  /** 카드·목록용 짧은 한글 제목 (수식 없음) */
  listTitle: llmStringField().optional(),
  imageQualityWarning: z.boolean().optional().default(false),
  visionImageClarityScore: z.number().min(0).max(1).optional(),
  visionExtractionConfidence: z.number().min(0).max(1).optional(),
});

/** API 스키마·저장용 conceptTags 정규화 (최대 2개). */
export function normalizeConceptTags(
  tags: unknown,
  max = 2,
): string[] {
  if (!Array.isArray(tags)) return ["수학 연습"];
  const normalized = tags
    .filter((t): t is string => typeof t === "string")
    .map((t) => t.trim())
    .filter(Boolean);
  if (normalized.length === 0) return ["수학 연습"];
  return normalized.slice(0, max);
}

export const generatedProblemSchema = z.preprocess((raw) => {
  if (!raw || typeof raw !== "object") return raw;
  const o = raw as Record<string, unknown>;
  const next: Record<string, unknown> = { ...o };
  if (!("jsxGraph" in o)) {
    next.jsxGraph = null;
  }
  if (!("visualizationData" in o)) {
    next.visualizationData = null;
  }
  if (!("solutionVisualizationData" in o)) {
    next.solutionVisualizationData = null;
  }
  // MongoDB / migration may store null; Zod .optional() rejects null.
  if (next.choices === null || next.type === "free_response") {
    delete next.choices;
  }
  if (next.type === "multiple_choice") {
    delete next.answerFormat;
  }
  return next;
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
  conceptTags: z.array(z.string()).min(1).max(2),
  /** free_response 전용 — short_numeric | short_answer 만 허용 */
  answerFormat: z.enum(["short_numeric", "short_answer"]).optional(),
  chart: chartConfigSchema,
  /** 필요할 때만: 좌표평면 도형 (JSXGraph). 불필요하면 null — legacy, visualizationData 우선 */
  jsxGraph: jsxGraphDiagramSchema,
  /** 통합 시각화 (bake 후 static PNG) */
  visualizationData: visualizationDataSchema,
  /** 풀이 설명용 추가 시각화 */
  solutionVisualizationData: visualizationDataSchema,
  visualizationMigrationStatus: visualizationMigrationStatusSchema.optional(),
  visualizationMigrationError: z.string().nullable().optional(),
  /** 문제 은행 출처 — bank면 bankItemId와 함께 사용 */
  source: z.enum(["bank", "generated"]).optional().default("generated"),
  bankItemId: z.string().optional(),
}));

export const generatedProblemSetSchema = z.object({
  id: z.string(),
  submissionId: z.string(),
  title: z.string(),
  learningGoal: z.string(),
  problems: z.array(generatedProblemSchema).length(5),
});

/** Azure 생성 시 1~5문항 (은행 보충·단원 시드) */
export const generatedProblemSetFlexibleSchema = z.object({
  id: z.string(),
  submissionId: z.string(),
  title: z.string(),
  learningGoal: z.string(),
  problems: z.array(generatedProblemSchema).min(1).max(5),
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
export type {
  VisualizationData,
  VisualizationMigrationStatus,
} from "./visualization-schema";
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

export type ConceptStatusItem = {
  concept: string;
  misses: number;
  status: "weak" | "learning" | "strong";
  label: string;
};

export type WeeklyTrendPoint = {
  weekLabel: string;
  accuracy: number;
  summary: string;
};

export type CurriculumUnitProgress = {
  id: string;
  section: string;
  name: string;
  subtitle: string;
  percent: number;
  status: "done" | "learning" | "weak" | "none";
};

export type TodayMission = {
  title: string;
  subtitle: string;
  remainingCount: number;
  setId: string | null;
  conceptTags: string[];
};

export type ParentActionItem = {
  icon: string;
  title: string;
  subtitle: string;
};

export type ParentCoachingCard = {
  label: string;
  question: string;
  gradingPoint: string;
  context: string;
  sourceType: "submission" | "practice" | "fallback";
  sourceId: string | null;
  problemLabel: string | null;
};

export type ParentWrongExplainItem = {
  id: string;
  sourceType: "submission" | "practice";
  sourceId: string;
  title: string;
  concept: string;
  easyExplain: string;
  parentScript: string;
  problemSetId: string | null;
  imageUrl: string | null;
  imageThumbUrl?: string | null;
  createdAt: string;
};

export type WeeklyReportCycleStep = {
  step: number;
  label: string;
  title: string;
  text: string;
};

export type LearningProfile = {
  grade: string;
  insight: LearningInsight;
  stats: {
    accuracy: number;
    accuracyDelta: number;
    totalProblems: number;
    problemsDelta: number;
    streakWeeks: number;
  };
  mission: TodayMission | null;
  training: TrainingSnapshot;
  conceptStatus: ConceptStatusItem[];
  strongConcepts: { concept: string; score: number }[];
  weeklyTrend: WeeklyTrendPoint[];
  curriculumUnits: CurriculumUnitProgress[];
  curriculumByBand: Record<
    "e12" | "e34" | "e56" | "m1" | "m2" | "m3" | "h1" | "h2" | "h3",
    CurriculumUnitProgress[]
  >;
  chainWarning: string | null;
  parentCoachingCard: ParentCoachingCard | null;
  parentWrongExplains: ParentWrongExplainItem[];
  parentActions: ParentActionItem[];
  weeklyReport: {
    weekLabel: string;
    period: string;
    cycle: WeeklyReportCycleStep[];
    unitMastery: { name: string; percent: number }[];
  };
};

export type TeacherStudentOverview = {
  id: string;
  displayName: string;
  studentCode: string;
  accuracy: number;
  status: "danger" | "warning" | "normal" | "excellent";
  statusLabel: string;
  weakConcept: string;
  totalAttempts: number;
};

export type TeacherClassOverview = {
  totalStudents: number;
  atRiskCount: number;
  classAverageAccuracy: number;
  accuracyDelta: number;
  organizationName: string | null;
  dangerStudents: TeacherStudentOverview[];
  students: TeacherStudentOverview[];
  classUnitAverages: { name: string; percent: number }[];
  recommendations: { icon: string; title: string; subtitle: string }[];
};

export type UserRole = "student" | "parent" | "teacher";

export type OAuthProvider = "kakao" | "google" | "apple" | "email";

export type User = {
  id: string;
  role: UserRole | null;
  displayName: string;
  /** 가입 온보딩에서 수집한 나이 */
  age?: number;
  grade?: string;
  organizationName?: string;
  studentCode?: string;
  profileImageUrl?: string;
  email?: string;
  oauthProvider: OAuthProvider;
  oauthSubject: string;
  linkedDeviceIds: string[];
  profileComplete: boolean;
  createdAt: string;
};

export type StudentLink = {
  id: string;
  guardianUserId: string;
  studentUserId: string;
  guardianLabel?: string | null;
  createdAt: string;
};

export type LinkedStudentSummary = {
  id: string;
  displayName: string;
  studentCode: string;
  guardianLabel: string | null;
  profileImageUrl: string | null;
};

export type AuthSessionPayload = {
  userId: string;
};

/** 문제 은행에 저장되는 개별 문항 (개념·난이도·학년대 분류) */
export type ProblemBankItem = {
  id: string;
  contentHash: string;
  type: GeneratedProblem["type"];
  title: string;
  prompt: string;
  choices?: GeneratedProblem["choices"];
  correctAnswer: string;
  explanation: string;
  difficulty: GeneratedProblem["difficulty"];
  conceptTags: string[];
  /** 검색·매칭용 대표 개념 */
  conceptPrimary: string;
  gradeBand: string;
  /** 교육과정 단원 ID (예: m1-linear-equations) */
  unitId?: string;
  source: "ai_generated" | "imported";
  originSubmissionId?: string;
  active: boolean;
  deliveryCount: number;
  chart: GeneratedProblem["chart"];
  jsxGraph: GeneratedProblem["jsxGraph"];
  visualizationData?: VisualizationData | null;
  solutionVisualizationData?: VisualizationData | null;
  visualizationMigrationStatus?: VisualizationMigrationStatus;
  visualizationMigrationError?: string | null;
  createdAt: string;
};

/** 사용자에게 어떤 은행 문항을 언제 보냈는지 (중복 발송 방지) */
export type UserProblemDelivery = {
  id: string;
  userId: string;
  bankItemId: string;
  problemSetId: string;
  submissionId?: string;
  problemId: string;
  deliveredAt: string;
  outcome: "pending" | "correct" | "incorrect";
  attemptId?: string;
};

/** 스캔한 원본 문제 + 분석 결과 (오답 원인 학습 데이터) */
export type ScannedProblemRecord = {
  id: string;
  userId: string;
  submissionId: string;
  imageUrl: string | null;
  imageName: string;
  problemText: string;
  extractedStudentAnswer: string;
  inferredCorrectAnswer: string;
  errorSummary: string;
  solutionSteps: string[];
  weakConcepts: string[];
  recommendedFocus: string[];
  conceptTags: string[];
  conceptPrimary: string;
  gradeBand: string;
  createdAt: string;
};

/** 연습 중 틀린 기록 (풀이 과정 실수 패턴) */
export type PracticeMistakeRecord = {
  id: string;
  userId: string;
  attemptId: string;
  setId: string;
  problemId: string;
  bankItemId?: string;
  answer: string;
  expectedAnswer: string;
  conceptTags: string[];
  conceptPrimary: string;
  feedback: string;
  createdAt: string;
  /** 이후 같은 개념에서 정답을 맞춰 재학습 처리된 시각 */
  resolvedAt?: string;
  resolveAttemptId?: string;
};

export type TrainingFocusItem = {
  concept: string;
  missScore: number;
  status: "needs_training" | "relearned";
  label: string;
};

export type TrainingSnapshot = {
  available: boolean;
  hasLearningData: boolean;
  headline: string;
  description: string;
  focusConcepts: string[];
  focusItems: TrainingFocusItem[];
  activeSetId: string | null;
  remainingCount: number;
  totalMisses: number;
  relearnedCount: number;
};

export type DifficultyStats = {
  attempts: number;
  correct: number;
  incorrect: number;
};

export type ConceptMasteryEntry = {
  concept: string;
  easy: DifficultyStats;
  medium: DifficultyStats;
  hard: DifficultyStats;
  targetDifficulty: GeneratedProblem["difficulty"];
};

export type UserConceptMastery = {
  userId: string;
  concepts: Record<string, ConceptMasteryEntry>;
  updatedAt: string;
};

export type TrainingFeedItem = {
  id: string;
  bankItemId: string;
  concept: string;
  difficulty: GeneratedProblem["difficulty"];
  reason: string;
  title: string;
  promptPreview: string;
  problemCount: number;
};

export type UserFeedQueue = {
  userId: string;
  items: TrainingFeedItem[];
  source: "precomputed" | "fallback";
  updatedAt: string;
};

export type AnalysisJobType = "refresh_user_feed" | "refresh_user_profile";

export type AnalysisJob = {
  id: string;
  userId: string;
  type: AnalysisJobType;
  status: "pending" | "processing" | "done" | "failed";
  createdAt: string;
  startedAt?: string;
  finishedAt?: string;
  error?: string;
  attempts: number;
};

export type TrainingFeedResponse = {
  items: TrainingFeedItem[];
  source: UserFeedQueue["source"];
  updatedAt: string | null;
  refreshPending: boolean;
};
