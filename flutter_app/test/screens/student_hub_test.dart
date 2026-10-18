import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:math_lens_tutor/dev/design_review_data.dart';
import 'package:math_lens_tutor/models/app_models.dart';
import 'package:math_lens_tutor/screens/student_hub_screen.dart';
import 'package:math_lens_tutor/services/api_client.dart';
import 'package:math_lens_tutor/services/auth_session.dart';
import 'package:math_lens_tutor/services/oauth_service.dart';
import 'package:math_lens_tutor/widgets/glass.dart';
import 'package:math_lens_tutor/widgets/home_stage.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _hub({
  required LearningProfile profile,
  required List<SubmissionSummary> subs,
  bool guest = false,
  EdgeInsets inset = EdgeInsets.zero,
}) {
  final auth = AuthSession();
  return MaterialApp(
    // 떠 있는 탭바가 `extendBody`로 만드는 아래 여백(그리고 상태 표시줄)을 흉내 낸다.
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(padding: inset),
      child: child!,
    ),
    home: Scaffold(
      body: StudentHubScreen(
        apiClient: ApiClient(authSession: auth),
        oauthService: OAuthService(),
        demoProfile: profile,
        demoSubmissions: subs,
        demoIsGuest: guest,
        demoUser: const AppUser(
          id: 'u1',
          displayName: '지민',
          profileComplete: true,
          grade: '중1',
          organizationName: '한빛중학교',
        ),
        demoToday: DateTime(2026, 10, 17),
      ),
    ),
  );
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    'first visit: steps, example, coach, no wordmark or upload button',
    (tester) async {
      await tester.pumpWidget(
        _hub(
          profile: designReviewProfileFirstVisit(),
          subs: designReviewSubmissionsEmpty(),
        ),
      );
      await tester.pumpAndSettle();
      for (final t in [
        '오늘은 한 장만\n올려도 돼요',
        '숙제 한 장 찍기',
        '막힌 곳 짚기',
        '이어서 풀기',
        '앨범에서 사진 고르기',
        '이렇게 짚어줘요',
        '여기를 눌러 숙제 한 장 찍어요',
      ]) {
        expect(find.text(t), findsWidgets);
      }
      expect(find.text('우열'), findsNothing);
      expect(find.text('숙제 올리기'), findsNothing);
    },
  );

  testWidgets('first visit: example circles "= 20" in red and explains', (
    tester,
  ) async {
    await tester.pumpWidget(
      _hub(
        profile: designReviewProfileFirstVisit(),
        subs: designReviewSubmissionsEmpty(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('= 20'), findsOneWidget);
    final circle = find.ancestor(
      of: find.text('= 20'),
      matching: find.byWidgetPredicate((w) {
        if (w is! DecoratedBox) return false;
        final d = w.decoration;
        return d is BoxDecoration &&
            d.border == Border.all(color: const Color(0xFFE5484D), width: 2.5);
      }),
    );
    expect(circle, findsOneWidget);
    expect(find.text('여기서 막혔어요'), findsOneWidget);
    expect(find.text('분과 시간 단위를 섞었어요. 20분은 1/3시간이에요.'), findsOneWidget);
  });

  testWidgets('first visit: coach bubble does not block taps to the camera', (
    tester,
  ) async {
    await tester.pumpWidget(
      _hub(
        profile: designReviewProfileFirstVisit(),
        subs: designReviewSubmissionsEmpty(),
      ),
    );
    await tester.pumpAndSettle();

    final nearest = tester.firstWidget<IgnorePointer>(
      find.ancestor(
        of: find.byType(GlassCoachBubble),
        matching: find.byType(IgnorePointer),
      ),
    );
    expect(nearest.ignoring, isTrue);
  });

  testWidgets('first visit as guest: signup row sits under the steps', (
    tester,
  ) async {
    await tester.pumpWidget(
      _hub(
        profile: designReviewProfileFirstVisit(),
        subs: designReviewSubmissionsEmpty(),
        guest: true,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('반가워요'), findsOneWidget);
    expect(find.text('둘러보는 중'), findsOneWidget);
    expect(find.text('둘러보는 중이에요. 가입하면 기록이 남아요.'), findsOneWidget);
    expect(find.text('가입하기'), findsOneWidget);
  });

  testWidgets('returning: mission, white continue button, streak, recent', (
    tester,
  ) async {
    await tester.pumpWidget(
      _hub(
        profile: designReviewProfileReturning(),
        subs: designReviewSubmissionsRecent(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('어제 막힌 곳부터\n이어가요'), findsOneWidget);
    // designReviewProfileReturning streakWeeks = 2
    expect(find.text('2주 연속'), findsOneWidget);
    expect(find.text('최근'), findsOneWidget);
    final cta = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, '이어서 풀기'),
    );
    expect(cta.style!.backgroundColor!.resolve({}), Colors.white);
  });

  testWidgets('returning: mission card, stats, and recent rows', (
    tester,
  ) async {
    await tester.pumpWidget(
      _hub(
        profile: designReviewProfileReturning(),
        subs: designReviewSubmissionsRecent(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('일차방정식 · 3문제 남음'), findsOneWidget);
    expect(find.text('일차방정식 유사문제'), findsOneWidget);
    expect(find.text('정답률'), findsOneWidget);
    expect(find.text('72%'), findsOneWidget);
    expect(find.text('해결한 문제'), findsOneWidget);
    expect(find.text('18개'), findsOneWidget);
    expect(find.text('2장'), findsOneWidget);
    expect(find.text('일차방정식'), findsWidgets);
    expect(find.text('가입하기'), findsNothing);
    expect(find.text('우열'), findsNothing);
  });

  testWidgets('returning: mission card has no progress bar', (tester) async {
    await tester.pumpWidget(
      _hub(
        profile: designReviewProfileReturning(),
        subs: designReviewSubmissionsRecent(),
      ),
    );
    await tester.pumpAndSettle();

    // 미션에는 전체 문제 수가 없어서 진행률을 계산할 수 없다 — 막대도, 진행률 라벨도 없다.
    expect(
      find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.label == '진행률',
      ),
      findsNothing,
    );
    expect(find.byType(LinearProgressIndicator), findsNothing);
    final missionCard = find.ancestor(
      of: find.widgetWithText(FilledButton, '이어서 풀기'),
      matching: find.byType(GlassSurface),
    );
    expect(missionCard, findsOneWidget);
    expect(
      find.descendant(
        of: missionCard,
        matching: find.byType(FractionallySizedBox),
      ),
      findsNothing,
    );
    // 단원 · 남은 문제 수, 제목, 버튼은 그대로 있다.
    expect(find.text('일차방정식 · 3문제 남음'), findsOneWidget);
    expect(find.text('일차방정식 유사문제'), findsOneWidget);
  });

  testWidgets('returning without a mission: stats stay, no continue button', (
    tester,
  ) async {
    await tester.pumpWidget(
      _hub(
        profile: designReviewProfileFirstVisit(),
        subs: designReviewSubmissionsRecent(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('어제 막힌 곳부터\n이어가요'), findsOneWidget);
    expect(find.text('정답률'), findsOneWidget);
    expect(find.text('시작 전'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, '이어서 풀기'), findsNothing);
  });

  testWidgets('guest with history: guest row and signup row', (tester) async {
    await tester.pumpWidget(
      _hub(
        profile: designReviewProfileReturning(),
        subs: designReviewSubmissionsRecent(),
        guest: true,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('반가워요'), findsOneWidget);
    expect(find.text('둘러보는 중'), findsOneWidget);
    expect(find.text('2주 연속'), findsNothing);
    expect(find.text('가입하기'), findsOneWidget);
  });

  for (final first in [true, false]) {
    testWidgets(
      'no content glass outside the stage (${first ? 'first visit' : 'returning'})',
      (tester) async {
        await tester.pumpWidget(
          _hub(
            profile: first
                ? designReviewProfileFirstVisit()
                : designReviewProfileReturning(),
            subs: first
                ? designReviewSubmissionsEmpty()
                : designReviewSubmissionsRecent(),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(GlassPanel), findsNothing);
        expect(find.byType(GlassButton), findsNothing);
      },
    );
  }

  group('layout', () {
    void phone(WidgetTester tester, double width) {
      tester.view.physicalSize = Size(width * 3, 844 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
    }

    final cases = <String, Widget Function()>{
      'first visit': () => _hub(
        profile: designReviewProfileFirstVisit(),
        subs: designReviewSubmissionsEmpty(),
      ),
      'first visit guest': () => _hub(
        profile: designReviewProfileFirstVisit(),
        subs: designReviewSubmissionsEmpty(),
        guest: true,
      ),
      'returning': () => _hub(
        profile: designReviewProfileReturning(),
        subs: designReviewSubmissionsRecent(),
      ),
      'returning guest': () => _hub(
        profile: designReviewProfileReturning(),
        subs: designReviewSubmissionsRecent(),
        guest: true,
      ),
    };

    for (final width in [320.0, 390.0]) {
      for (final entry in cases.entries) {
        testWidgets('${entry.key} fits ${width.toInt()}dp wide', (tester) async {
          phone(tester, width);
          await tester.pumpWidget(entry.value());
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        });
      }
    }

    testWidgets('stage reaches the top edge; coach bubble sits above the bar', (
      tester,
    ) async {
      phone(tester, 390);
      await tester.pumpWidget(
        _hub(
          profile: designReviewProfileFirstVisit(),
          subs: designReviewSubmissionsEmpty(),
          inset: const EdgeInsets.only(top: 47, bottom: 110),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.getTopLeft(find.byType(HomeStage)).dy, 0);
      // 말풍선 아래(꼬리 끝)는 탭바 위쪽에서 8px 뜬다.
      expect(
        tester.getBottomLeft(find.byType(GlassCoachBubble)).dy,
        844 - 110 - 8,
      );
      expect(tester.getCenter(find.byType(GlassCoachBubble)).dx, 195);
    });

    testWidgets('last recent row scrolls above the floating bar', (
      tester,
    ) async {
      phone(tester, 390);
      await tester.pumpWidget(
        _hub(
          profile: designReviewProfileReturning(),
          subs: designReviewSubmissionsRecent(),
          inset: const EdgeInsets.only(top: 47, bottom: 110),
        ),
      );
      await tester.pumpAndSettle();

      await tester.drag(find.byType(ListView), const Offset(0, -2000));
      await tester.pumpAndSettle();
      final lastRow = find.text('소인수분해').first;
      expect(tester.getBottomLeft(lastRow).dy, lessThanOrEqualTo(844 - 110));
    });
  });
}
