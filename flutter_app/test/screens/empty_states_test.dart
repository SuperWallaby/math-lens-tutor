import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:math_lens_tutor/dev/design_review_data.dart';
import 'package:math_lens_tutor/models/app_models.dart';
import 'package:math_lens_tutor/screens/student_progress_screen.dart';
import 'package:math_lens_tutor/screens/student_training_screen.dart';
import 'package:math_lens_tutor/services/api_client.dart';
import 'package:math_lens_tutor/services/auth_session.dart';
import 'package:math_lens_tutor/widgets/glass.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Title as the screen draws it inside the scroll view. [GlassScrollEdge]
/// repeats the same text outside it, so a bare `find.text` would match twice.
Finder _titleInScroll(String title) => find.descendant(
      of: find.byType(Scrollable),
      matching: find.text(title),
    );

Widget _training({
  required LearningProfile profile,
  TrainingFeedResponse? feed,
}) {
  return MaterialApp(
    home: Scaffold(
      body: StudentTrainingScreen(
        apiClient: ApiClient(authSession: AuthSession()),
        demoProfile: profile,
        demoFeed: feed ??
            const TrainingFeedResponse(
              items: [],
              source: 'precomputed',
              updatedAt: '2026-10-17T00:00:00Z',
              refreshPending: false,
            ),
      ),
    ),
  );
}

Widget _progress({bool viewAsGuardian = false}) {
  return MaterialApp(
    home: Scaffold(
      body: StudentProgressScreen(
        apiClient: ApiClient(authSession: AuthSession()),
        viewAsGuardian: viewAsGuardian,
        demoProfile: designReviewProfileFirstVisit(),
        demoInitialGradeTab: 3,
      ),
    ),
  );
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('training empty state, no learning data', (tester) async {
    await tester.pumpWidget(_training(profile: designReviewProfileFirstVisit()));
    await tester.pumpAndSettle();

    expect(_titleInScroll('훈련'), findsOneWidget);
    for (final t in [
      '아직 훈련할 문제가 없어요',
      '숙제를 찍으면 막힌 개념이 여기에 모여요.',
      '이런 식으로 쌓여요',
      '가운데 카메라로 시작해요',
    ]) {
      expect(find.text(t), findsOneWidget);
    }
    expect(find.text('막힌 개념만 모아서 다시 풀어보는 곳이에요.'), findsOneWidget);
    expect(find.text('아직 훈련할 항목이 없습니다'), findsNothing);
  });

  testWidgets('training empty state shows two dimmed example rows',
      (tester) async {
    await tester.pumpWidget(_training(profile: designReviewProfileFirstVisit()));
    await tester.pumpAndSettle();

    expect(
      find.text('단위 바꾸기 (분 → 시간) · 일차방정식의 활용 · 3문제'),
      findsOneWidget,
    );
    expect(find.text('분배법칙 부호 · 문자와 식 · 2문제'), findsOneWidget);
    // 예시는 실제 항목이 아니므로 55% 투명도로 흐리게 보인다.
    final dimmed = tester.widget<Opacity>(
      find
          .ancestor(
            of: find.text('분배법칙 부호 · 문자와 식 · 2문제'),
            matching: find.byType(Opacity),
          )
          .first,
    );
    expect(dimmed.opacity, closeTo(0.55, 0.001));
  });

  testWidgets('training empty state with learning data hides the examples',
      (tester) async {
    const solvedAll = TrainingSnapshot(
      available: false,
      hasLearningData: true,
      headline: '',
      description: '',
      focusConcepts: [],
      focusItems: [],
      activeSetId: null,
      remainingCount: 0,
      totalMisses: 3,
      relearnedCount: 3,
    );
    final profile = designReviewProfileFirstVisit();
    await tester.pumpWidget(
      _training(profile: _withTraining(profile, solvedAll)),
    );
    await tester.pumpAndSettle();

    expect(_titleInScroll('훈련'), findsOneWidget);
    expect(find.text('막힌 문제를 다 풀었어요.'), findsOneWidget);
    expect(find.text('새로 막히면 여기에 모여요.'), findsOneWidget);
    expect(find.text('아직 훈련할 문제가 없어요'), findsNothing);
    expect(find.text('이런 식으로 쌓여요'), findsNothing);
    expect(find.text('가운데 카메라로 시작해요'), findsNothing);
    expect(find.text('아직 훈련할 항목이 없습니다'), findsNothing);
  });

  testWidgets('training list keeps its title and gets the scroll edge',
      (tester) async {
    await tester.pumpWidget(
      _training(
        profile: designReviewProfileFirstVisit(),
        feed: designReviewTrainingFeed(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('맞춤 훈련'), findsOneWidget);
    expect(find.text('이런 식으로 쌓여요'), findsNothing);
    expect(find.byType(GlassScrollEdge), findsOneWidget);
    expect(
      tester.widget<GlassScrollEdge>(find.byType(GlassScrollEdge)).title,
      '훈련',
    );
  });

  testWidgets('scroll edge appears after scrolling the training empty state',
      (tester) async {
    tester.view.physicalSize = const Size(390, 420);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_training(profile: designReviewProfileFirstVisit()));
    await tester.pumpAndSettle();

    expect(
      tester.widget<GlassScrollEdge>(find.byType(GlassScrollEdge)).visible,
      isFalse,
    );
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -200));
    await tester.pumpAndSettle();
    expect(
      tester.widget<GlassScrollEdge>(find.byType(GlassScrollEdge)).visible,
      isTrue,
    );
  });

  testWidgets('progress empty state', (tester) async {
    await tester.pumpWidget(_progress());
    await tester.pumpAndSettle();

    expect(_titleInScroll('내 진도'), findsOneWidget);
    expect(find.text('내 진도 현황'), findsNothing);
    expect(find.textContaining('숙제를 찍으면 그 단원부터 채워져요.'), findsOneWidget);
    expect(find.textContaining(RegExp(r'^0 / \d+ 단원$')), findsOneWidget);
    expect(find.text('시작 전'), findsWidgets);
    expect(find.text('미시작'), findsNothing);
  });

  testWidgets('progress empty state shows every grade unit at an empty bar',
      (tester) async {
    await tester.pumpWidget(_progress());
    await tester.pumpAndSettle();

    // 0%인 줄의 진행 막대는 빈 막대(value 0)여야 하고, 끝없이 도는 막대가 아니다.
    final bars = tester
        .widgetList<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
        .toList();
    expect(bars, isNotEmpty);
    expect(bars.every((bar) => bar.value == 0), isTrue);
    // 구간은 데모가 정한 중1이고, 프로필의 학년(초1)이 덮어쓰지 않는다.
    expect(find.text('2022 개정 교육과정 · 중1'), findsOneWidget);
    expect(find.text('0 / 9 단원'), findsOneWidget);
  });

  testWidgets('progress with some progress hides the intro card',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StudentProgressScreen(
            apiClient: ApiClient(authSession: AuthSession()),
            demoProfile: designReviewProfileGradeM1(),
            demoInitialGradeTab: 3,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(_titleInScroll('내 진도'), findsOneWidget);
    expect(find.textContaining('숙제를 찍으면 그 단원부터 채워져요.'), findsNothing);
    expect(find.textContaining(RegExp(r'^0 / \d+ 단원$')), findsNothing);
  });

  testWidgets('guardian view keeps its own title and has no student intro',
      (tester) async {
    await tester.pumpWidget(_progress(viewAsGuardian: true));
    await tester.pumpAndSettle();

    expect(find.text('내 진도'), findsNothing);
    expect(find.textContaining('숙제를 찍으면 그 단원부터 채워져요.'), findsNothing);
  });

  testWidgets('scroll edge appears after scrolling the progress tab',
      (tester) async {
    await tester.pumpWidget(_progress());
    await tester.pumpAndSettle();

    expect(
      tester.widget<GlassScrollEdge>(find.byType(GlassScrollEdge)).visible,
      isFalse,
    );
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -200));
    await tester.pumpAndSettle();
    expect(
      tester.widget<GlassScrollEdge>(find.byType(GlassScrollEdge)).visible,
      isTrue,
    );
  });
}

/// `LearningProfile` has no `copyWith`, so rebuild the one we need.
LearningProfile _withTraining(LearningProfile p, TrainingSnapshot training) {
  return LearningProfile(
    grade: p.grade,
    insight: p.insight,
    stats: p.stats,
    conceptStatus: p.conceptStatus,
    strongConcepts: p.strongConcepts,
    weeklyTrend: p.weeklyTrend,
    curriculumUnits: p.curriculumUnits,
    curriculumByBand: p.curriculumByBand,
    chainWarning: p.chainWarning,
    parentActions: p.parentActions,
    weeklyReport: p.weeklyReport,
    training: training,
  );
}
