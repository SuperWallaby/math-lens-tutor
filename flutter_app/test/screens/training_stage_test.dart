import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:math_lens_tutor/dev/design_review_data.dart';
import 'package:math_lens_tutor/models/app_models.dart';
import 'package:math_lens_tutor/screens/student_training_screen.dart';
import 'package:math_lens_tutor/services/api_client.dart';
import 'package:math_lens_tutor/services/app_prefs.dart';
import 'package:math_lens_tutor/services/auth_session.dart';
import 'package:math_lens_tutor/theme/app_design_system.dart';
import 'package:math_lens_tutor/widgets/glass.dart';
import 'package:math_lens_tutor/widgets/learning_profile_widgets.dart';
import 'package:math_lens_tutor/widgets/page_stage.dart';
import 'package:math_lens_tutor/widgets/skeleton_box.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _emptyFeed = TrainingFeedResponse(
  items: [],
  source: 'precomputed',
  updatedAt: '2026-10-17T00:00:00Z',
  refreshPending: false,
);

/// 문제 1개 + 2개짜리 피드 → 「풀 문제」 3개.
const _feed = TrainingFeedResponse(
  items: [
    TrainingFeedItem(
      id: 'feed_1',
      bankItemId: 'bank_linear',
      concept: '일차방정식',
      difficulty: 'medium',
      reason: '오답 2회 복습',
      title: '일차방정식 이항',
      promptPreview: '2x + 5 = 13',
    ),
    TrainingFeedItem(
      id: 'feed_2',
      bankItemId: 'bank_factor',
      concept: '소인수분해',
      difficulty: 'easy',
      reason: '오답 1회 복습',
      title: '최소공배수',
      promptPreview: '24와 36',
      problemCount: 2,
    ),
  ],
  source: 'precomputed',
  updatedAt: '2026-10-17T00:00:00Z',
  refreshPending: false,
);

TrainingSnapshot _snapshot({
  bool available = true,
  bool hasLearningData = true,
  String? activeSetId,
  int remainingCount = 0,
}) {
  return TrainingSnapshot(
    available: available,
    hasLearningData: hasLearningData,
    headline: '',
    description: '',
    focusConcepts: const ['일차방정식', '소인수분해'],
    focusItems: const [],
    activeSetId: activeSetId,
    remainingCount: remainingCount,
    totalMisses: 4,
    relearnedCount: 2,
  );
}

/// `LearningProfile` has no `copyWith`, so rebuild the one we need.
LearningProfile _withTraining(TrainingSnapshot training) {
  final p = designReviewProfileFirstVisit();
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

Widget _training({
  required LearningProfile profile,
  TrainingFeedResponse feed = _emptyFeed,
  ApiClient? api,
}) {
  return MaterialApp(
    home: Scaffold(
      body: StudentTrainingScreen(
        apiClient: api ?? ApiClient(authSession: AuthSession()),
        demoProfile: api == null ? profile : null,
        demoFeed: api == null ? feed : null,
      ),
    ),
  );
}

Finder _onStage(Finder f) =>
    find.descendant(of: find.byType(PageStage), matching: f);

Finder _tileWith(String label, String value) => find.byWidgetPredicate(
  (w) => w is StageTile && w.label == label && w.value == value,
);

/// 프로필·피드 요청 수를 세는 가짜 서버. [hold]가 끝날 때까지 응답을 붙잡을 수 있다.
class _CountingApi extends ApiClient {
  _CountingApi({this.hold}) : super(authSession: AuthSession());

  final Completer<void>? hold;
  int profileCalls = 0;

  @override
  Future<LearningProfile> getLearningProfile({
    bool forceRefresh = false,
    LearningProfileScope scope = LearningProfileScope.full,
  }) async {
    profileCalls++;
    if (hold != null) await hold!.future;
    return _withTraining(_snapshot());
  }

  @override
  Future<TrainingFeedResponse> getTrainingFeed({
    bool forceRefresh = false,
  }) async => _feed;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    resetAppPrefsCache();
  });

  testWidgets('review set: white 5-problem button and two tiles on the stage', (
    tester,
  ) async {
    await tester.pumpWidget(
      _training(profile: _withTraining(_snapshot()), feed: _feed),
    );
    await tester.pumpAndSettle();

    expect(_onStage(find.text('훈련')), findsOneWidget);
    expect(_onStage(find.text('막힌 개념만 모아서 다시 풀어봐요')), findsOneWidget);

    final button = _onStage(find.text('5문제 세트로 복습'));
    expect(button, findsOneWidget);
    final style = tester
        .widget<FilledButton>(
          find.ancestor(of: button, matching: find.byType(FilledButton)),
        )
        .style!;
    expect(style.backgroundColor!.resolve({}), Colors.white);
    expect(style.foregroundColor!.resolve({}), AppColors.primary);

    expect(_onStage(find.text('일차방정식 · 소인수분해')), findsOneWidget);
    expect(_onStage(find.textContaining('누적 오답 4건')), findsOneWidget);
    expect(find.textContaining('재학습 성공'), findsNothing);

    expect(_tileWith('풀 문제', '3개'), findsOneWidget);
    expect(_tileWith('다시 맞힘', '2건'), findsOneWidget);

    final section = find.widgetWithText(SectionLabel, '풀 문제');
    expect(section, findsOneWidget);
    expect(
      find.descendant(of: find.byType(PageStage), matching: section),
      findsNothing,
    );
    expect(find.text('맞춤 문제'), findsNothing);
    expect(find.byType(GlassScrollEdge), findsNothing);
  });

  testWidgets('continue set: white continue button with the remaining count', (
    tester,
  ) async {
    await tester.pumpWidget(
      _training(
        profile: _withTraining(
          _snapshot(activeSetId: 'set-1', remainingCount: 2),
        ),
        feed: _feed,
      ),
    );
    await tester.pumpAndSettle();

    expect(_onStage(find.text('이어서 복습하기')), findsOneWidget);
    expect(_onStage(find.text('틀렸던 개념 문제 · 2개 남음')), findsOneWidget);
    expect(find.text('5문제 세트로 복습'), findsNothing);
  });

  testWidgets('feed only: the stage says how many problems are ready', (
    tester,
  ) async {
    await tester.pumpWidget(
      _training(
        profile: _withTraining(_snapshot(available: false)),
        feed: _feed,
      ),
    );
    await tester.pumpAndSettle();

    expect(_onStage(find.text('풀 문제 3개가 준비됐어요')), findsOneWidget);
    expect(find.byType(FilledButton), findsNothing);
  });

  testWidgets('solved everything: done message and both tiles', (
    tester,
  ) async {
    await tester.pumpWidget(
      _training(profile: _withTraining(_snapshot(available: false))),
    );
    await tester.pumpAndSettle();

    expect(_onStage(find.text('막힌 문제를 다 풀었어요.')), findsOneWidget);
    expect(_onStage(find.text('새로 막히면 여기에 모여요.')), findsOneWidget);
    expect(find.byType(StageTile), findsNWidgets(2));
    expect(_tileWith('풀 문제', '0개'), findsOneWidget);
  });

  testWidgets('first visit: empty card on the stage, camera hint below', (
    tester,
  ) async {
    await tester.pumpWidget(
      _training(profile: designReviewProfileFirstVisit()),
    );
    await tester.pumpAndSettle();

    expect(_onStage(find.text('아직 훈련할 문제가 없어요')), findsOneWidget);
    expect(_onStage(find.text('숙제를 찍으면 막힌 개념이 여기에 모여요.')), findsOneWidget);
    expect(find.text('가운데 카메라로 시작해요'), findsOneWidget);
    expect(_onStage(find.text('가운데 카메라로 시작해요')), findsNothing);
    expect(find.text('이런 식으로 쌓여요'), findsOneWidget);
    expect(find.byType(StageTile), findsNothing);
  });

  testWidgets('first visit: the camera hint sits above the floating tab bar', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MediaQuery(
        // extendBody 탭바가 body에 넘기는 아래 여백(30 + 72 + 24).
        data: const MediaQueryData(
          size: Size(390, 844),
          padding: EdgeInsets.only(top: 47, bottom: 126),
        ),
        child: _training(profile: designReviewProfileFirstVisit()),
      ),
    );
    await tester.pumpAndSettle();

    // 스크롤하지 않아도 안내가 탭바 위에 보여야 가운데 카메라를 가리킬 수 있다.
    expect(
      tester.getRect(find.text('가운데 카메라로 시작해요')).bottom,
      lessThanOrEqualTo(844 - 126),
    );
  });

  testWidgets('loading: the stage shows, skeletons below, no tiles', (
    tester,
  ) async {
    final hold = Completer<void>();
    final api = _CountingApi(hold: hold);
    await tester.pumpWidget(
      _training(profile: designReviewProfileFirstVisit(), api: api),
    );
    await tester.pump();

    expect(_onStage(find.text('훈련')), findsOneWidget);
    expect(find.byType(SkeletonBox), findsWidgets);
    expect(find.byType(StageTile), findsNothing);

    hold.complete();
    await tester.pumpAndSettle();
    expect(find.byType(StageTile), findsNWidgets(2));
  });

  testWidgets('pulling down reloads the training tab', (tester) async {
    final api = _CountingApi();
    await tester.pumpWidget(
      _training(profile: designReviewProfileFirstVisit(), api: api),
    );
    await tester.pumpAndSettle();
    expect(api.profileCalls, 1);

    await tester.fling(
      find.byType(Scrollable).first,
      const Offset(0, 400),
      1000,
    );
    await tester.pumpAndSettle();
    expect(api.profileCalls, 2);
  });

  testWidgets('the status-bar band appears after scrolling', (tester) async {
    tester.view.physicalSize = const Size(390, 420);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _training(profile: _withTraining(_snapshot()), feed: _feed),
    );
    await tester.pumpAndSettle();

    expect(
      tester.widget<GlassStatusBarBand>(find.byType(GlassStatusBarBand)).visible,
      isFalse,
    );
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -200));
    await tester.pumpAndSettle();
    expect(
      tester.widget<GlassStatusBarBand>(find.byType(GlassStatusBarBand)).visible,
      isTrue,
    );
  });
}
