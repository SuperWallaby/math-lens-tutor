import type {
  GeneratedProblemSet,
  LearningInsight,
  ProblemAttempt,
  SolutionAnalysis,
  SolutionSubmission,
} from "./types";

export const sampleAnalysis: SolutionAnalysis = {
  problemText:
    "이차함수 $y = x^2 - 4x + 3$ 의 최솟값을 구하시오. (이차항 계수 $a \\ne 0$)",
  extractedStudentAnswer: "3번, 0",
  inferredCorrectAnswer: "$-1$",
  confidence: 0.82,
  solutionSteps: [
    "학생은 $x^2 - 4x + 3$을 $(x - 2)^2 + 3$으로 완전제곱식 변형했습니다.",
    "상수항 보정에서 $-4 + 3 = -1$을 반영하지 않아 최솟값을 $3$으로 판단했습니다.",
  ],
  referenceSolutionSteps: [
    "$y = x^2 - 4x + 3 = (x-2)^2 - 1$ 로 완전제곱식으로 변형합니다.",
    "$(x-2)^2 \\ge 0$ 이므로 $y \\ge -1$ 입니다.",
    "따라서 최솟값은 $-1$ 입니다.",
  ],
  errorSummary:
    "완전제곱식으로 바꿀 때 더하고 뺀 값의 보정이 빠져 최솟값을 잘못 읽었습니다.",
  weakConcepts: ["완전제곱식", "이차함수의 꼭짓점", "상수항 보정"],
  recommendedFocus: [
    "$x^2 + bx$를 $\\bigl(x + \\frac{b}{2}\\bigr)^2$ 형태로 바꾼 뒤 보정항을 확인하기",
    "꼭짓점 좌표와 최솟값을 구분해서 쓰기",
  ],
  imageQualityWarning: false,
  visionImageClarityScore: 0.92,
  visionExtractionConfidence: 0.9,
};

export const sampleProblemSet: GeneratedProblemSet = {
  id: "demo-set",
  submissionId: "demo-submission",
  title: "완전제곱식과 이차함수 최솟값 연습",
  learningGoal: "상수항 보정 실수를 줄이고 꼭짓점에서 최솟값을 읽는 연습",
  problems: [
    {
      id: "demo-problem-1",
      type: "multiple_choice",
      title: "최솟값 구하기",
      prompt: "이차함수 $y = x^2 - 6x + 5$ 의 최솟값은?",
      choices: [
        { id: "1", label: "-9" },
        { id: "2", label: "-4" },
        { id: "3", label: "0" },
        { id: "4", label: "5" },
        { id: "5", label: "9" },
      ],
      correctAnswer: "-4",
      explanation:
        "$x^2 - 6x + 5 = (x - 3)^2 - 4$ 이므로 최솟값은 $-4$입니다.",
      difficulty: "easy",
      conceptTags: ["완전제곱식", "최솟값"],
      chart: null,
      jsxGraph: null,
    },
    {
      id: "demo-problem-2",
      type: "multiple_choice",
      title: "꼭짓점 읽기",
      prompt: "y = (x + 1)^2 - 7의 꼭짓점은?",
      choices: [
        { id: "1", label: "(1, -7)" },
        { id: "2", label: "(-1, -7)" },
        { id: "3", label: "(-1, 7)" },
        { id: "4", label: "(1, 7)" },
        { id: "5", label: "(0, -7)" },
      ],
      correctAnswer: "(-1, -7)",
      explanation: "y = (x - p)^2 + q의 꼭짓점은 (p, q)입니다.",
      difficulty: "easy",
      conceptTags: ["꼭짓점"],
      chart: null,
      jsxGraph: null,
    },
    {
      id: "demo-problem-3",
      type: "free_response",
      title: "완전제곱식 변형",
      prompt: "x^2 + 8x + 10을 완전제곱식 형태로 고치세요.",
      correctAnswer: "(x + 4)^2 - 6",
      explanation: "x^2 + 8x = (x + 4)^2 - 16이므로 전체는 (x + 4)^2 - 6입니다.",
      difficulty: "medium",
      conceptTags: ["완전제곱식", "상수항 보정"],
      chart: null,
      jsxGraph: null,
    },
    {
      id: "demo-problem-4",
      type: "multiple_choice",
      title: "그래프 최솟값",
      prompt: "아래 그래프에 해당하는 y = x^2 - 2x - 3의 최솟값은?",
      choices: [
        { id: "1", label: "-4" },
        { id: "2", label: "-3" },
        { id: "3", label: "0" },
        { id: "4", label: "1" },
        { id: "5", label: "4" },
      ],
      correctAnswer: "-4",
      explanation: "x^2 - 2x - 3 = (x - 1)^2 - 4입니다.",
      difficulty: "medium",
      conceptTags: ["그래프", "최솟값"],
      chart: {
        type: "line",
        data: {
          labels: [-2, -1, 0, 1, 2, 3, 4],
          datasets: [
            {
              label: "y = x^2 - 2x - 3",
              data: [5, 0, -3, -4, -3, 0, 5],
              borderColor: "#2563eb",
              backgroundColor: "rgba(37, 99, 235, 0.15)",
            },
          ],
        },
        options: { responsive: true },
      },
      jsxGraph: null,
    },
    {
      id: "demo-problem-5",
      type: "free_response",
      title: "오류 찾기",
      prompt:
        "학생이 x^2 - 10x + 21 = (x - 5)^2 + 21이라고 썼습니다. 빠진 보정항을 포함해 올바르게 고치세요.",
      correctAnswer: "(x - 5)^2 - 4",
      explanation: "(x - 5)^2 = x^2 - 10x + 25이므로 21을 만들려면 -4가 필요합니다.",
      difficulty: "hard",
      conceptTags: ["오류 분석", "상수항 보정"],
      chart: null,
      jsxGraph: {
        diagramNeeded: true,
        captionKo: "예시: 좌표평면 삼각형 (JSXGraph 데모)",
        rationaleKo: "기하 형태 확인용 데모입니다.",
        board: {
          boundingbox: [-2, 10, 12, -2],
          axis: true,
          keepaspectratio: true,
        },
        elements: [
          {
            id: "A",
            elType: "point",
            coord: [2, 6],
            attrs: { name: "A", fixed: true, strokeColor: "#1d4ed8" },
          },
          {
            id: "B",
            elType: "point",
            coord: [8, 6],
            attrs: { name: "B", fixed: true, strokeColor: "#1d4ed8" },
          },
          {
            id: "C",
            elType: "point",
            coord: [5, 2],
            attrs: { name: "C", fixed: true, strokeColor: "#1d4ed8" },
          },
          {
            elType: "polygon",
            parents: ["A", "B", "C"],
            attrs: {
              borders: {
                strokeWidth: 2,
                strokeColor: "#2563eb",
              },
            },
          },
        ],
      },
    },
  ],
};

export const sampleSubmission: SolutionSubmission = {
  id: "demo-submission",
  userId: "demo-user",
  imageUrl: null,
  imageName: "sample-quadratic.jpg",
  createdAt: new Date().toISOString(),
  analysis: sampleAnalysis,
};

export function buildSampleInsight(attempts: ProblemAttempt[]): LearningInsight {
  const totalAttempts = attempts.length;
  const correct = attempts.filter((attempt) => attempt.isCorrect).length;
  const accuracy = totalAttempts ? Math.round((correct / totalAttempts) * 100) : 0;

  return {
    levelLabel:
      accuracy >= 80 ? "안정권" : accuracy >= 50 ? "개념 보완 중" : "기초 재점검 필요",
    masteryScore: accuracy,
    totalAttempts,
    accuracy,
    weakConcepts: [
      { concept: "상수항 보정", misses: Math.max(1, totalAttempts - correct) },
      { concept: "완전제곱식", misses: Math.max(0, totalAttempts - correct - 1) },
      { concept: "그래프 해석", misses: Math.max(0, totalAttempts - correct - 2) },
    ],
    recentFeedback: [
      "완전제곱식 변형 후 마지막 상수항을 다시 검산하세요.",
      "꼭짓점의 x좌표와 함수의 최솟값을 구분해 적는 연습이 필요합니다.",
    ],
    trendChart: {
      type: "bar",
      data: {
        labels: ["정답", "오답"],
        datasets: [
          {
            label: "최근 풀이 결과",
            data: [correct, totalAttempts - correct],
            backgroundColor: ["#16a34a", "#dc2626"],
          },
        ],
      },
      options: { responsive: true },
    },
  };
}
