import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:math_lens_tutor/dev/design_review_data.dart';
import 'package:math_lens_tutor/models/app_models.dart';
import 'package:math_lens_tutor/screens/student_progress_screen.dart';
import 'package:math_lens_tutor/screens/student_training_screen.dart';
import 'package:math_lens_tutor/services/api_client.dart';
import 'package:math_lens_tutor/services/app_prefs.dart';
import 'package:math_lens_tutor/services/auth_session.dart';
import 'package:math_lens_tutor/widgets/glass.dart';
import 'package:math_lens_tutor/widgets/learning_profile_widgets.dart';
import 'package:math_lens_tutor/widgets/skeleton_box.dart';
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
  AuthSession? session,
}) {
  return MaterialApp(
    home: Scaffold(
      body: StudentTrainingScreen(
        apiClient: ApiClient(authSession: session ?? AuthSession()),
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

Widget _progress({bool viewAsGuardian = false, AuthSession? session}) {
  return MaterialApp(
    home: Scaffold(
      body: StudentProgressScreen(
        apiClient: ApiClient(authSession: session ?? AuthSession()),
        viewAsGuardian: viewAsGuardian,
        demoProfile: designReviewProfileFirstVisit(),
        demoInitialGradeTab: 3,
      ),
    ),
  );
}

/// A session with one linked child, loaded the way the app does (from prefs).
///
/// Without a linked child `GuardianLearningGate` shows its "link a child"
/// screen and never builds the progress content, so the guardian view needs this.
Future<AuthSession> _guardianSession(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({
    'linked_students': jsonEncode([
      const LinkedStudent(
        id: 'student-1',
        displayName: '지민',
        studentCode: '123456',
      ).toJson(),
    ]),
  });
  resetAppPrefsCache();
  final session = AuthSession();
  await tester.runAsync(session.load);
  expect(session.linkedStudents, hasLength(1));
  return session;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    resetAppPrefsCache();
  });

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

    // 빈 상태·스크롤 상단과 같은 제목과 해요체 설명. 옛 「맞춤 훈련」 말투는 없다.
    expect(_titleInScroll('훈련'), findsOneWidget);
    expect(find.text('막힌 개념만 모아서 다시 풀어보는 곳이에요.'), findsOneWidget);
    expect(find.text('맞춤 훈련'), findsNothing);
    expect(find.text('당신을 위한 문제를 추천합니다.'), findsNothing);
    expect(find.text('이런 식으로 쌓여요'), findsNothing);
    expect(find.byType(GlassScrollEdge), findsOneWidget);
    expect(
      tester.widget<GlassScrollEdge>(find.byType(GlassScrollEdge)).title,
      '훈련',
    );
  });

  group('training hero speaks 해요체 when the API sends no headline', () {
    const noHeadline = TrainingSnapshot(
      available: true,
      hasLearningData: true,
      headline: '',
      description: '',
      focusConcepts: ['일차방정식'],
      focusItems: [],
      activeSetId: null,
      remainingCount: 0,
      totalMisses: 3,
      relearnedCount: 0,
    );

    testWidgets('without a name', (tester) async {
      await tester.pumpWidget(
        _training(
          profile: _withTraining(designReviewProfileFirstVisit(), noHeadline),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('막힌 개념으로 문제를 준비했어요.'), findsOneWidget);
      expect(find.text('맞춤 문제가 준비되었습니다.'), findsNothing);
    });

    testWidgets('with the student name', (tester) async {
      SharedPreferences.setMockInitialValues({
        'auth_user': jsonEncode(
          const AppUser(id: 'u1', displayName: '지민', profileComplete: true)
              .toJson(),
        ),
      });
      resetAppPrefsCache();
      final session = AuthSession();
      await tester.runAsync(session.load);
      expect(session.user?.displayName, '지민');

      await tester.pumpWidget(
        _training(
          profile: _withTraining(designReviewProfileFirstVisit(), noHeadline),
          session: session,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('지민님, 막힌 개념으로 문제를 준비했어요.'), findsOneWidget);
      expect(find.text('지민님을 위한 맞춤 문제가 준비되었습니다.'), findsNothing);
    });
  });

  test('training screen has no 합니다체 copy left', () {
    // 훈련 대상 목록의 빈 줄처럼 화면으로 띄우기 어려운 글자도 함께 본다.
    final source =
        File('lib/screens/student_training_screen.dart').readAsStringSync();
    final formal = RegExp(r"'[^'\n]*니다[^'\n]*'");
    expect(formal.allMatches(source).map((m) => m.group(0)), isEmpty);
  });

  testWidgets('training skeleton shows the same title while loading',
      (tester) async {
    await tester.pumpWidget(
      _training(
        profile: designReviewProfileFirstVisit(),
        feed: designReviewTrainingFeed(),
      ),
    );
    // 첫 프레임: 아직 불러오는 중이라 자리표시 카드가 보인다.
    expect(find.byType(SkeletonBox), findsWidgets);
    expect(_titleInScroll('훈련'), findsOneWidget);
    expect(find.text('막힌 개념만 모아서 다시 풀어보는 곳이에요.'), findsOneWidget);
    expect(find.text('복습 훈련'), findsNothing);
    expect(find.text('맞춤 피드'), findsNothing);
    await tester.pumpAndSettle();
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
    final session = await _guardianSession(tester);
    await tester.pumpWidget(_progress(viewAsGuardian: true, session: session));
    await tester.pumpAndSettle();

    // 진도 본문이 실제로 그려졌는지부터 확인한다. 연결된 자녀가 없을 때의
    // 안내 화면에는 구간 선택도 단원 줄도 없다.
    expect(find.byType(GradeBandTabBar), findsOneWidget);
    expect(find.text('① 소인수분해'), findsOneWidget);
    expect(find.text('단원을 눌러 자녀에게 어떻게 도와줄지 확인하세요'), findsOneWidget);
    expect(find.text('지민'), findsWidgets);

    expect(_titleInScroll('교육과정 진도'), findsOneWidget);
    expect(find.text('내 진도'), findsNothing);
    expect(find.text('내 진도 현황'), findsNothing);
    expect(find.textContaining('숙제를 찍으면 그 단원부터 채워져요.'), findsNothing);
    expect(find.textContaining(RegExp(r'^0 / \d+ 단원$')), findsNothing);
    expect(find.byType(GlassScrollEdge), findsNothing);

    // 시작 전인 단원은 빈 진행 막대로 보인다.
    expect(find.text('시작 전'), findsWidgets);
    final bars = tester
        .widgetList<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
        .toList();
    expect(bars, isNotEmpty);
    expect(bars.every((bar) => bar.value == 0), isTrue);
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
