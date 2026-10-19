import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:math_lens_tutor/dev/design_review_data.dart';
import 'package:math_lens_tutor/models/app_models.dart';
import 'package:math_lens_tutor/screens/dashboard_screen.dart';
import 'package:math_lens_tutor/screens/student_progress_screen.dart';
import 'package:math_lens_tutor/services/api_client.dart';
import 'package:math_lens_tutor/services/app_prefs.dart';
import 'package:math_lens_tutor/services/auth_session.dart';
import 'package:math_lens_tutor/widgets/glass.dart';
import 'package:math_lens_tutor/widgets/learning_profile_widgets.dart';
import 'package:math_lens_tutor/widgets/page_stage.dart';
import 'package:math_lens_tutor/widgets/skeleton_box.dart';
import 'package:math_lens_tutor/widgets/student_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _progress({
  LearningProfile? profile,
  ApiClient? api,
  bool viewAsGuardian = false,
  AuthSession? session,
}) {
  return MaterialApp(
    home: Scaffold(
      body: StudentProgressScreen(
        apiClient: api ?? ApiClient(authSession: session ?? AuthSession()),
        viewAsGuardian: viewAsGuardian,
        demoProfile: profile,
        demoInitialGradeTab: 3,
      ),
    ),
  );
}

Finder _onStage(Finder f) =>
    find.descendant(of: find.byType(PageStage), matching: f);

StageTile _tile(WidgetTester tester, String label) => tester.widget<StageTile>(
  find.byWidgetPredicate((w) => w is StageTile && w.label == label),
);

/// 프로필 요청 수를 세는 가짜 서버. [hold]가 끝날 때까지 응답을 붙잡을 수 있다.
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
    return designReviewProfileGradeM1();
  }
}

Future<AuthSession> _guardianWithTwoChildren(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({
    'linked_students': jsonEncode([
      for (final s in const [
        LinkedStudent(id: 's1', displayName: '지민', studentCode: '123456'),
        LinkedStudent(id: 's2', displayName: '서준', studentCode: '654321'),
      ])
        s.toJson(),
    ]),
  });
  resetAppPrefsCache();
  final session = AuthSession();
  await tester.runAsync(session.load);
  return session;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    resetAppPrefsCache();
  });

  test('finished units counts units at 100% in the band', () {
    final units = designReviewProfileGradeM1().unitsForGradeTab(3);
    final r = finishedUnits(units);
    expect(r.total, units.length);
    expect(r.done, units.where((u) => u.percent >= 100).length);
  });

  testWidgets('student: title, curriculum line, pills, tiles and stats button', (
    tester,
  ) async {
    final profile = designReviewProfileGradeM1();
    await tester.pumpWidget(_progress(profile: profile));
    await tester.pumpAndSettle();

    expect(_onStage(find.text('내 진도')), findsOneWidget);
    expect(_onStage(find.text('2022 개정 교육과정 · 중1')), findsOneWidget);
    expect(_onStage(find.byType(GradeBandTabBar)), findsOneWidget);
    expect(
      tester.widget<GradeBandTabBar>(find.byType(GradeBandTabBar)).onStage,
      isTrue,
    );
    expect(_onStage(find.byTooltip('학습 통계')), findsOneWidget);

    final r = finishedUnits(profile.unitsForGradeTab(3));
    expect(_tile(tester, '끝낸 단원').value, '${r.done} / ${r.total}');
    final accuracy = profile.stats.accuracy;
    expect(
      _tile(tester, '정답률').value,
      accuracy > 0 ? '$accuracy%' : '시작 전',
    );
    expect(find.byType(GlassScrollEdge), findsNothing);
  });

  testWidgets('not started: the hint replaces the curriculum line', (
    tester,
  ) async {
    await tester.pumpWidget(_progress(profile: designReviewProfileFirstVisit()));
    await tester.pumpAndSettle();

    expect(_onStage(find.text('숙제를 찍으면 그 단원부터 채워져요.')), findsOneWidget);
    expect(find.text('2022 개정 교육과정 · 중1'), findsNothing);
    expect(_tile(tester, '끝낸 단원').value, '0 / 9');
    expect(find.text('0 / 9 단원'), findsNothing);
  });

  testWidgets('guardian: child picker on the stage, guardian copy', (
    tester,
  ) async {
    final session = await _guardianWithTwoChildren(tester);
    await tester.pumpWidget(
      _progress(
        profile: designReviewProfileFirstVisit(),
        viewAsGuardian: true,
        session: session,
      ),
    );
    await tester.pumpAndSettle();

    expect(_onStage(find.byType(StudentPicker)), findsOneWidget);
    expect(
      tester.widget<StudentPicker>(find.byType(StudentPicker)).onStage,
      isTrue,
    );
    expect(_onStage(find.text('지민')), findsOneWidget);
    expect(_onStage(find.text('교육과정 진도')), findsOneWidget);
    expect(
      _onStage(find.text('단원을 눌러 자녀에게 어떻게 도와줄지 확인하세요')),
      findsOneWidget,
    );
    expect(find.text('내 진도'), findsNothing);
    expect(_onStage(find.byTooltip('학생 학습 통계')), findsOneWidget);
    expect(find.byType(GlassScrollEdge), findsNothing);
  });

  testWidgets('the stats circle opens learning stats', (tester) async {
    await tester.pumpWidget(_progress(profile: designReviewProfileGradeM1()));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('학습 통계'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(DashboardScreen), findsOneWidget);
  });

  testWidgets('loading: the stage shows, no tiles, no old loading title', (
    tester,
  ) async {
    final hold = Completer<void>();
    await tester.pumpWidget(_progress(api: _CountingApi(hold: hold)));
    await tester.pump();

    expect(_onStage(find.text('내 진도')), findsOneWidget);
    expect(find.text('진도 불러오는 중'), findsNothing);
    expect(find.byType(SkeletonBox), findsWidgets);
    expect(find.byType(StageTile), findsNothing);

    hold.complete();
    await tester.pumpAndSettle();
    expect(find.byType(StageTile), findsNWidgets(2));
  });

  testWidgets('pulling down reloads the growth tab', (tester) async {
    final api = _CountingApi();
    await tester.pumpWidget(_progress(api: api));
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
}
