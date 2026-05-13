import '../models/app_models.dart';

/// App Store 스크린샷 전용 정적 데모 (API 없이 동일 UI 노출).
AnalyzeResult storeScreenshotAnalyzeResult() {
  const analysis = SolutionAnalysis(
    problemText:
        '함수 f(x) = x² − 4x + 3 의 최솟값을 구하고, 그때의 x 값을 구하시오.',
    extractedStudentAnswer: '최솟값 −1, x = 2',
    inferredCorrectAnswer: '최솟값 −1, x = 2',
    isLikelyCorrect: true,
    confidence: 0.88,
    solutionSteps: [
      '완전제곱식으로 f(x) = (x − 2)² − 1 로 정리했습니다.',
      '꼭짓점이 (2, −1) 이므로 최솟값은 −1 입니다.',
    ],
    errorSummary: '계산 과정은 일관되며, 꼭짓점 해석도 올바릅니다.',
    weakConcepts: ['이차함수 꼭짓점', '완전제곱식'],
    recommendedFocus: [
      '매개변수가 있는 이차함수 최댓값·최솟값',
      '닫힌 구간에서의 최댓·최솟',
    ],
  );

  final submission = SolutionSubmission(
    id: 'demo_submission',
    userId: 'demo_user',
    imageUrl: null,
    imageName: '풀이_사진_예시.jpg',
    createdAt: '2026-05-07T12:00:00Z',
    analysis: analysis,
  );

  final problemSet = GeneratedProblemSet(
    id: 'demo_set',
    submissionId: submission.id,
    title: '이차함수·최솟값 집중 훈련',
    learningGoal: '꼭짓점과 구간에서의 최솟값을 빠르게 판별합니다.',
    problems: [
      GeneratedProblem(
        id: 'p1',
        type: 'multiple_choice',
        title: '개념 확인',
        prompt: 'f(x) = (x − 2)² − 1 일 때 최솟값은?',
        choices: [
          ProblemChoice(id: '1', label: '−2'),
          ProblemChoice(id: '2', label: '−1'),
          ProblemChoice(id: '3', label: '0'),
          ProblemChoice(id: '4', label: '1'),
          ProblemChoice(id: '5', label: '2'),
        ],
        correctAnswer: '2',
        explanation: '꼭짓점의 y좌표가 최솟값입니다.',
        difficulty: 'easy',
        conceptTags: ['이차함수'],
        chart: {
          'type': 'bar',
          'data': {
            'datasets': [
              {'data': [3.0, 1.0, 0.0, 1.0, 3.0]},
            ],
          },
        },
      ),
      GeneratedProblem(
        id: 'p2',
        type: 'free_response',
        title: '서술형',
        prompt: 'f(x) = x² − 6x + 10 의 최솟값과 그때의 x 를 구하시오.',
        choices: const [],
        correctAnswer: '최솟값 1, x = 3',
        explanation: 'f(x) = (x − 3)² + 1',
        difficulty: 'medium',
        conceptTags: ['완전제곱'],
        chart: null,
      ),
    ],
  );

  return AnalyzeResult(submission: submission, problemSet: problemSet);
}

LearningInsight storeScreenshotLearningInsight() {
  return const LearningInsight(
    levelLabel: '중급',
    masteryScore: 72,
    totalAttempts: 48,
    accuracy: 68,
    weakConcepts: [
      WeakConcept(concept: '이차함수 꼭짓점', misses: 5),
      WeakConcept(concept: '삼각비 응용', misses: 3),
      WeakConcept(concept: '수열 합 공식', misses: 2),
    ],
    recentFeedback: [
      '꼭짓점 좌표를 구한 뒤 구간 끝값과 비교하는 습관을 들이세요.',
      '서술형에서는 중간 과정을 한 줄이라도 남기면 채점 안정성이 올라갑니다.',
    ],
  );
}
