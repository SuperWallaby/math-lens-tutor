import '../models/app_models.dart';
import 'store_screenshot_data.dart';

CurriculumUnitProgress _unit({
  required String id,
  required String section,
  required String name,
  required String subtitle,
  int percent = 0,
  String status = 'none',
}) {
  return CurriculumUnitProgress(
    id: id,
    section: section,
    name: name,
    subtitle: subtitle,
    percent: percent,
    status: status,
  );
}

List<CurriculumUnitProgress> _e12Units() => [
      _unit(
        id: 'e12-numbers-9',
        section: '1. 수와 연산',
        name: '① 9까지의 수',
        subtitle: '수 세기·수 읽기·수 쓰기·수의 순서',
      ),
      _unit(
        id: 'e12-numbers-50',
        section: '1. 수와 연산',
        name: '② 50까지의 수',
        subtitle: '두 자리 수·수직선·수의 크기 비교',
      ),
      _unit(
        id: 'e12-add-sub',
        section: '1. 수와 연산',
        name: '③ 덧셈과 뺄셈',
        subtitle: '받아올림·받아내림·세 자리 수',
      ),
      _unit(
        id: 'e12-shapes',
        section: '2. 도형',
        name: '④ 여러 가지 도형',
        subtitle: '삼각형·사각형·원·도형 만들기',
      ),
      _unit(
        id: 'e12-measure',
        section: '3. 측정',
        name: '⑤ 길이와 시간',
        subtitle: '길이 재기·시각·날짜·시간',
      ),
      _unit(
        id: 'e12-patterns',
        section: '4. 규칙성',
        name: '⑥ 규칙 찾기',
        subtitle: '규칙성·패턴·배열',
      ),
    ];

List<CurriculumUnitProgress> _m1Units({bool withProgress = false}) => [
      _unit(
        id: 'm1-factor',
        section: 'Ⅰ. 수와 연산',
        name: '① 소인수분해',
        subtitle: '소수·합성수·소인수분해·최대공약수·최소공배수',
        percent: withProgress ? 85 : 0,
        status: withProgress ? 'done' : 'none',
      ),
      _unit(
        id: 'm1-integers',
        section: 'Ⅰ. 수와 연산',
        name: '② 정수와 유리수',
        subtitle: '양수·음수·절댓값·유리수의 사칙연산',
        percent: withProgress ? 62 : 0,
        status: withProgress ? 'learning' : 'none',
      ),
      _unit(
        id: 'm1-expressions',
        section: 'Ⅱ. 문자와 식',
        name: '③ 문자의 사용과 식',
        subtitle: '문자 사용·식의 값·일차식 계산',
        percent: withProgress ? 38 : 0,
        status: withProgress ? 'weak' : 'none',
      ),
      _unit(
        id: 'm1-equations',
        section: 'Ⅱ. 문자와 식',
        name: '④ 일차방정식',
        subtitle: '방정식의 풀이·활용',
      ),
      _unit(
        id: 'm1-coordinates',
        section: 'Ⅲ. 좌표평면과 그래프',
        name: '⑤ 좌표평면과 그래프',
        subtitle: '순서쌍·좌표·좌표평면',
      ),
      _unit(
        id: 'm1-proportion-graph',
        section: 'Ⅲ. 좌표평면과 그래프',
        name: '⑥ 정비례와 반비례',
        subtitle: '정비례·반비례 관계와 그래프',
      ),
      _unit(
        id: 'm1-basic-shapes',
        section: 'Ⅳ. 기본 도형',
        name: '⑦ 기본 도형',
        subtitle: '점·선·면·각·위치 관계',
      ),
      _unit(
        id: 'm1-plane-shapes',
        section: 'Ⅴ. 평면도형',
        name: '⑧ 평면도형',
        subtitle: '삼각형·사각형·원·다각형',
      ),
      _unit(
        id: 'm1-statistics',
        section: 'Ⅵ. 통계',
        name: '⑨ 자료의 정리와 해석',
        subtitle: '도수분포표·히스토그램·줄기-잎 그림',
      ),
    ];


LearningProfile designReviewProfileFirstVisit() {
  final e12 = _e12Units();
  return LearningProfile(
    grade: '초1',
    insight: const LearningInsight(
      levelLabel: '시작',
      masteryScore: 0,
      totalAttempts: 0,
      accuracy: 0,
      weakConcepts: [],
      recentFeedback: [],
    ),
    stats: const LearningStats(
      accuracy: 0,
      accuracyDelta: 0,
      totalProblems: 0,
      problemsDelta: 0,
      streakWeeks: 0,
    ),
    conceptStatus: const [],
    strongConcepts: const [],
    weeklyTrend: const [],
    curriculumUnits: e12,
    curriculumByBand: {'e12': e12},
    chainWarning: null,
    parentActions: const [],
    weeklyReport: const WeeklyReport(
      weekLabel: '',
      period: '',
      cycle: [],
      unitMastery: [],
    ),
    training: TrainingSnapshot.empty,
  );
}

LearningProfile designReviewProfileReturning() {
  final m1 = _m1Units(withProgress: true);
  return LearningProfile(
    grade: '중1',
    insight: LearningInsight(
      levelLabel: '중급',
      masteryScore: 68,
      totalAttempts: 42,
      accuracy: 71,
      weakConcepts: const [
        WeakConcept(concept: '일차방정식', misses: 3),
      ],
      recentFeedback: const [
        '이항할 때 부호를 다시 확인해 보세요.',
      ],
    ),
    stats: const LearningStats(
      accuracy: 71,
      accuracyDelta: 4,
      totalProblems: 48,
      problemsDelta: 6,
      streakWeeks: 2,
    ),
    mission: const TodayMission(
      title: '일차방정식 유사문제',
      subtitle: '3문항 남음',
      remainingCount: 3,
      setId: 'demo_mission_set',
      conceptTags: ['일차방정식'],
    ),
    conceptStatus: const [],
    strongConcepts: const [
      StrongConcept(concept: '소인수분해', score: 88),
    ],
    weeklyTrend: const [
      WeeklyTrendPoint(weekLabel: '4/28', accuracy: 62, summary: ''),
      WeeklyTrendPoint(weekLabel: '5/5', accuracy: 68, summary: ''),
      WeeklyTrendPoint(weekLabel: '5/12', accuracy: 71, summary: ''),
    ],
    curriculumUnits: m1,
    curriculumByBand: {'m1': m1},
    chainWarning: null,
    parentActions: const [],
    weeklyReport: const WeeklyReport(
      weekLabel: '5월 2주',
      period: '5/5–5/11',
      cycle: [],
      unitMastery: [],
    ),
    training: TrainingSnapshot(
      available: true,
      hasLearningData: true,
      headline: '틀렸던 개념을 다시 연습해요',
      description:
          '분석·연습에서 틀린 부분을 모아 비슷한 문제로 반복 훈련합니다. 맞추면 [재학습 성공됨]으로 표시돼요.',
      focusConcepts: const ['일차방정식'],
      focusItems: const [
        TrainingFocusItem(
          concept: '일차방정식',
          missScore: 3,
          status: 'needs_training',
          label: '복습 필요',
        ),
        TrainingFocusItem(
          concept: '소인수분해',
          missScore: 1,
          status: 'relearned',
          label: '재학습 성공됨',
        ),
      ],
      activeSetId: null,
      remainingCount: 0,
      totalMisses: 3,
      relearnedCount: 1,
    ),
  );
}

LearningProfile designReviewProfileGradeE12() => designReviewProfileFirstVisit();

LearningProfile designReviewProfileGradeM1() {
  final m1 = _m1Units(withProgress: true);
  return LearningProfile(
    grade: '중1',
    insight: storeScreenshotLearningInsight(),
    stats: const LearningStats(
      accuracy: 68,
      accuracyDelta: 2,
      totalProblems: 32,
      problemsDelta: 4,
      streakWeeks: 1,
    ),
    conceptStatus: const [],
    strongConcepts: const [],
    weeklyTrend: const [],
    curriculumUnits: m1,
    curriculumByBand: {'m1': m1},
    chainWarning: null,
    parentActions: const [],
    weeklyReport: const WeeklyReport(
      weekLabel: '',
      period: '',
      cycle: [],
      unitMastery: [],
    ),
    training: TrainingSnapshot.empty,
  );
}

LearningProfile designReviewProfileChainWarning() {
  final m1 = _m1Units(withProgress: true);
  return LearningProfile(
    grade: '중1',
    insight: storeScreenshotLearningInsight(),
    stats: const LearningStats(
      accuracy: 55,
      accuracyDelta: -3,
      totalProblems: 28,
      problemsDelta: 2,
      streakWeeks: 0,
    ),
    conceptStatus: const [],
    strongConcepts: const [],
    weeklyTrend: const [],
    curriculumUnits: m1,
    curriculumByBand: {'m1': m1},
    chainWarning: '일차방정식이 약하면 중2 연립방정식 전에 보완이 필요해요!',
    parentActions: const [],
    weeklyReport: const WeeklyReport(
      weekLabel: '',
      period: '',
      cycle: [],
      unitMastery: [],
    ),
    training: TrainingSnapshot.empty,
  );
}

LearningProfile designReviewProfileParent() {
  final m1 = _m1Units(withProgress: true);
  return LearningProfile(
    grade: '중1',
    insight: LearningInsight(
      levelLabel: '중급',
      masteryScore: 68,
      totalAttempts: 42,
      accuracy: 71,
      weakConcepts: const [
        WeakConcept(concept: '최소공배수', misses: 2),
      ],
      recentFeedback: const [
        'GCD를 더하는 이유를 설명해 보세요.',
      ],
    ),
    stats: const LearningStats(
      accuracy: 71,
      accuracyDelta: 4,
      totalProblems: 24,
      problemsDelta: 6,
      streakWeeks: 2,
    ),
    parentCoachingCard: const ParentCoachingCard(
      label: '오늘의 부모 코칭',
      question: '오늘 자녀에게: "21번에서 GCD를 왜 더해야 한다고 생각해?"',
      gradingPoint: '최소공배수 = (두 수의 곱) ÷ 최대공약수',
      context: '24와 36의 최소공배수를 구하는 문제',
      sourceType: 'submission',
      sourceId: 'demo_sub',
      problemLabel: '21번',
    ),
    parentWrongExplains: const [
      ParentWrongExplainItem(
        id: 'demo-wrong-1',
        sourceType: 'submission',
        sourceId: 'demo_sub',
        title: '21번',
        concept: '최소공배수',
        easyExplain:
            '24와 36의 최소공배수는 72입니다. GCD 12를 구한 뒤 (24×36)÷12 로 계산해요.',
        parentScript:
            '「최소공배수」에서 "GCD를 더해야 한다" — 아이에게 왜 그렇게 생각했는지 설명해 달라고 해보세요.',
        problemSetId: 'demo_set',
        createdAt: '2026-05-26T10:00:00Z',
      ),
    ],
    parentActions: const [
      ParentActionItem(
        icon: '💬',
        title: '오늘 코칭 질문 해보기',
        subtitle: '오늘 자녀에게: "21번에서 GCD를 왜 더해야 한다고 생각해?"',
      ),
      ParentActionItem(
        icon: '📖',
        title: '틀린 문제, 이렇게 설명해 주세요',
        subtitle: '24와 36의 최소공배수는 72입니다…',
      ),
    ],
    conceptStatus: const [],
    strongConcepts: const [
      StrongConcept(concept: '소인수분해', score: 88),
    ],
    weeklyTrend: const [],
    curriculumUnits: m1,
    curriculumByBand: {'m1': m1},
    chainWarning: null,
    weeklyReport: const WeeklyReport(
      weekLabel: '이번 주',
      period: '2026.06.16 ~ 06.22',
      cycle: [
        WeeklyReportStep(
          step: 5,
          label: '부모 확인',
          title: '부모님이 확인할 것',
          text: '자녀가 유사문제를 끝까지 풀었는지 확인해 주세요.',
        ),
        WeeklyReportStep(
          step: 6,
          label: '대화하기',
          title: '오늘의 코칭 질문',
          text: '「GCD를 더해야 한다」— 왜 그렇게 생각했는지 물어보세요.',
        ),
        WeeklyReportStep(
          step: 7,
          label: '채점 포인트',
          title: '핵심 채점 포인트',
          text: '최소공배수 = (두 수의 곱) ÷ 최대공약수',
        ),
      ],
      unitMastery: [
        UnitMastery(name: '소인수분해', percent: 90),
        UnitMastery(name: '최소공배수', percent: 55),
      ],
    ),
    training: TrainingSnapshot.empty,
  );
}

List<SubmissionSummary> designReviewSubmissionsEmpty() => const [];

List<SubmissionSummary> designReviewSubmissionsRecent() => const [
      SubmissionSummary(
        id: 'sub_1',
        title: '2x + 5 = 13 일 때, x의 값을 구하시오.',
        listTitle: '일차방정식',
        createdAt: '2026-05-26T10:00:00Z',
        weakConcepts: ['일차방정식'],
      ),
      SubmissionSummary(
        id: 'sub_2',
        title: '24와 36의 최소공배수를 구하시오.',
        listTitle: '소인수분해',
        createdAt: '2026-05-24T15:30:00Z',
        weakConcepts: ['소인수분해'],
      ),
    ];

AnalyzeResult designReviewAnalyzeResultWeak() {
  const analysis = SolutionAnalysis(
    problemText: '2x + 5 = 13 일 때, x의 값을 구하시오.',
    extractedStudentAnswer: 'x = 3',
    inferredCorrectAnswer: 'x = 4',
    confidence: 0.82,
    solutionSteps: [
      '2x + 5 = 13',
      '2x = 8',
      'x = 3',
    ],
    errorSummary: '양변에서 5를 뺄 때 부호를 반대로 처리했습니다.',
    weakConcepts: ['일차방정식', '이항'],
    recommendedFocus: ['일차방정식 이항 연습', '양변에 같은 수 더하기·빼기'],
    imageQualityWarning: false,
  );

  final submission = SolutionSubmission(
    id: 'review_weak',
    userId: 'demo',
    imageUrl: null,
    imageName: '일차방정식_풀이.jpg',
    createdAt: '2026-05-26T12:00:00Z',
    analysis: analysis,
  );

  return AnalyzeResult(
    submission: submission,
    problemSet: storeScreenshotAnalyzeResult().problemSet,
  );
}

AnalyzeResult designReviewAnalyzeResultOk() {
  const analysis = SolutionAnalysis(
    problemText: 'f(x) = x² − 4x + 3 의 최솟값을 구하시오.',
    extractedStudentAnswer: '최솟값 −1, x = 2',
    inferredCorrectAnswer: '최솟값 −1, x = 2',
    confidence: 0.91,
    solutionSteps: [
      'f(x) = (x − 2)² − 1',
      '최솟값 −1, x = 2',
    ],
    errorSummary: '풀이가 정확합니다.',
    weakConcepts: [],
    recommendedFocus: ['매개변수가 있는 이차함수 심화'],
    imageQualityWarning: false,
  );

  final submission = SolutionSubmission(
    id: 'review_ok',
    userId: 'demo',
    imageUrl: null,
    imageName: '이차함수_풀이.jpg',
    createdAt: '2026-05-26T11:00:00Z',
    analysis: analysis,
  );

  return AnalyzeResult(
    submission: submission,
    problemSet: storeScreenshotAnalyzeResult().problemSet,
  );
}

GeneratedProblemSet designReviewProblemSet() =>
    storeScreenshotAnalyzeResult().problemSet;

GeneratedProblemSet designReviewProblemSetQuestion() {
  final full = designReviewProblemSet();
  return GeneratedProblemSet(
    id: full.id,
    submissionId: full.submissionId,
    title: '9까지의 수 · 순서 연습',
    learningGoal: '수의 순서를 보고 빈칸에 알맞은 수를 씁니다.',
    problems: [full.problems.first],
  );
}

/// 삼각함수 Desmos 그래프 디버그용 (design_review=practice__trig_graph)
GeneratedProblemSet designReviewProblemSetTrigGraph() {
  return GeneratedProblemSet(
    id: 'review_trig_set',
    submissionId: 'review_trig_sub',
    title: '삼각함수 · 주기 연습',
    learningGoal: '사인 그래프의 주기를 읽습니다.',
    problems: [
      GeneratedProblem(
        id: 'trig_p1',
        type: 'multiple_choice',
        title: '주기 구하기',
        prompt: r'아래 그래프 $y=\sin(3x)$ 의 주기는?',
        choices: const [
          ProblemChoice(id: '1', label: r'$\dfrac{2\pi}{3}$'),
          ProblemChoice(id: '2', label: r'$\dfrac{\pi}{3}$'),
          ProblemChoice(id: '3', label: r'$2\pi$'),
          ProblemChoice(id: '4', label: r'$\pi$'),
          ProblemChoice(id: '5', label: r'$3\pi$'),
        ],
        correctAnswer: '1',
        explanation: r'$\sin(3x)$ 의 주기는 $\dfrac{2\pi}{3}$ 입니다.',
        difficulty: 'medium',
        conceptTags: const ['삼각함수', 'sin'],
        chart: null,
        visualizationData: const {
          'type': 'function_graph',
          'engine': 'desmos',
          'data': {
            'expression': 'y=sin(3x)',
            'xRange': [-2, 2],
            'yRange': [-1.5, 1.5],
          },
        },
      ),
    ],
  );
}

GeneratedProblemSet designReviewProblemSetCompact() {
  final full = designReviewProblemSet();
  final p = full.problems.first;
  return GeneratedProblemSet(
    id: full.id,
    submissionId: full.submissionId,
    title: full.title,
    learningGoal: full.learningGoal,
    problems: [
      GeneratedProblem(
        id: p.id,
        type: p.type,
        title: p.title,
        prompt: p.prompt,
        choices: p.choices,
        correctAnswer: p.correctAnswer,
        explanation: p.explanation,
        difficulty: p.difficulty,
        conceptTags: p.conceptTags,
        chart: null,
        jsxGraph: p.jsxGraph,
        source: p.source,
        bankItemId: p.bankItemId,
      ),
    ],
  );
}

ProblemAttempt designReviewAttemptCorrect() {
  return const ProblemAttempt(
    id: 'att_ok',
    problemId: 'p1',
    answer: '2',
    isCorrect: true,
    feedback: '정답입니다. 꼭짓점의 y좌표가 최솟값이에요.',
  );
}

ProblemAttempt designReviewAttemptWrong() {
  return const ProblemAttempt(
    id: 'att_bad',
    problemId: 'p1',
    answer: '1',
    isCorrect: false,
    feedback: '−1이 정답이에요. (x−2)²−1 형태로 완전제곱식을 떠올려 보세요.',
  );
}

TrainingFeedResponse designReviewTrainingFeed() {
  return const TrainingFeedResponse(
    source: 'precomputed',
    updatedAt: '2026-05-26T12:00:00Z',
    refreshPending: false,
    items: [
      TrainingFeedItem(
        id: 'feed_1',
        bankItemId: 'bank_linear',
        concept: '일차방정식',
        difficulty: 'medium',
        reason: '오답 2회 복습',
        title: '일차방정식 이항',
        promptPreview: r'2x + 5 = 13 일 때, x의 값은?',
      ),
      TrainingFeedItem(
        id: 'feed_2',
        bankItemId: 'bank_factor',
        concept: '소인수분해',
        difficulty: 'easy',
        reason: '맞춤 추천',
        title: '최소공배수',
        promptPreview: '24와 36의 최소공배수를 구하시오.',
      ),
    ],
  );
}

/// Parses `screenId__state` from DESIGN_REVIEW / query param.
({String screen, String state}) parseDesignReviewKey(String raw) {
  final key = raw.trim();
  final sep = key.indexOf('__');
  if (sep <= 0 || sep >= key.length - 2) {
    return (screen: key, state: 'default');
  }
  return (
    screen: key.substring(0, sep),
    state: key.substring(sep + 2),
  );
}

const designReviewCaptureKeys = [
  'student_hub__first_visit',
  'student_hub__returning',
  'upload__idle',
  'analysis__analyzing',
  'analysis__result_weak',
  'analysis__result_ok',
  'practice__question',
  'practice__feedback_correct',
  'practice__feedback_wrong',
  'student_progress__grade_e12',
  'student_progress__grade_m1',
  'student_progress__chain_warning',
];
