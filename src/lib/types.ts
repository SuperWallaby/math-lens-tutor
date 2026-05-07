import { z } from "zod";

/** LLM 이 빈 배열을 줄 때가 있어 파싱 단계에서 최소 1개 보장 */
function stringArrayWithFallback(fallback: string) {
  return z
    .array(z.string())
    .transform((arr) => {
      const cleaned = arr.map((s) => s.trim()).filter(Boolean);
      return cleaned.length > 0 ? cleaned : [fallback];
    });
}

export const chartConfigSchema = z
  .object({
    type: z.enum(["bar", "line", "pie", "doughnut", "radar", "scatter"]),
    data: z.record(z.string(), z.unknown()),
    options: z.record(z.string(), z.unknown()).optional(),
  })
  .nullable();

export const solutionAnalysisSchema = z.object({
  problemText: z.string(),
  extractedStudentAnswer: z.string(),
  inferredCorrectAnswer: z.string(),
  isLikelyCorrect: z.boolean(),
  confidence: z.number().min(0).max(1),
  solutionSteps: stringArrayWithFallback(
    "이미지에서 풀이 단계를 명확히 구분하기 어렵습니다.",
  ),
  errorSummary: z.string(),
  weakConcepts: stringArrayWithFallback(
    "사진만으로는 부족한 개념을 특정하기 어렵습니다.",
  ),
  recommendedFocus: stringArrayWithFallback(
    "우선 동일 유형 문제를 조금 더 풀며 풀이 과정을 적는 연습을 권합니다.",
  ),
});

export const generatedProblemSchema = z.object({
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
});

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
export type UnifiedAnalyzeProblemSet = z.infer<
  typeof unifiedAnalyzeProblemSetSchema
>;

export type SolutionSubmission = {
  id: string;
  userId: string;
  imageUrl: string | null;
  imageName: string;
  createdAt: string;
  analysis: SolutionAnalysis;
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
