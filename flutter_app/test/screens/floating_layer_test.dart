import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:math_lens_tutor/dev/design_review_data.dart';
import 'package:math_lens_tutor/models/app_models.dart';
import 'package:math_lens_tutor/screens/loop_result_screen.dart';
import 'package:math_lens_tutor/screens/open_practice_flow.dart';
import 'package:math_lens_tutor/screens/parent_explain_screen.dart';
import 'package:math_lens_tutor/screens/practice_screen.dart';
import 'package:math_lens_tutor/screens/settings_screen.dart';
import 'package:math_lens_tutor/screens/signup_screen.dart';
import 'package:math_lens_tutor/services/api_client.dart';
import 'package:math_lens_tutor/services/app_prefs.dart';
import 'package:math_lens_tutor/services/auth_session.dart';
import 'package:math_lens_tutor/services/oauth_service.dart';
import 'package:math_lens_tutor/theme/app_design_system.dart';
import 'package:math_lens_tutor/widgets/app_card.dart';
import 'package:math_lens_tutor/widgets/glass.dart';
import 'package:math_lens_tutor/widgets/learning_profile_widgets.dart';
import 'package:math_lens_tutor/widgets/linked_children_panel.dart';
import 'package:math_lens_tutor/widgets/oauth_sign_in_button.dart';
import 'package:math_lens_tutor/widgets/parent_tab_scaffold.dart';
import 'package:math_lens_tutor/widgets/student_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _parent = AppUser(
  id: 'parent-1',
  displayName: '민준 어머니',
  profileComplete: true,
  role: AppUserRole.parent,
);

const _children = [
  LinkedStudent(id: 's1', displayName: '지민', studentCode: '123456'),
  LinkedStudent(id: 's2', displayName: '서연', studentCode: '654321'),
];

/// 학부모로 로그인한 세션 (자녀 둘 연결). 앱이 읽는 것과 같은 prefs 에서 불러온다.
Future<AuthSession> _signedInParent(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({
    'auth_token': 'token',
    'auth_user': jsonEncode(_parent.toJson()),
    'linked_students': jsonEncode([for (final s in _children) s.toJson()]),
  });
  resetAppPrefsCache();
  final session = AuthSession();
  await tester.runAsync(session.load);
  expect(session.isSignedIn, isTrue);
  return session;
}

Widget _settings(AuthSession session, {EdgeInsets inset = EdgeInsets.zero}) {
  return MaterialApp(
    theme: buildAppTheme(),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(padding: inset),
      child: child!,
    ),
    home: Scaffold(
      extendBody: true,
      body: SettingsScreen(
        apiClient: ApiClient(authSession: session),
        oauthService: OAuthService(),
      ),
    ),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    resetAppPrefsCache();
  });

  group('settings', () {
    testWidgets('account deletion asks in a glass dialog and 취소 leaves', (
      tester,
    ) async {
      final session = await _signedInParent(tester);
      await tester.pumpWidget(_settings(session));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('계정 탈퇴'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('계정 탈퇴'));
      await tester.pumpAndSettle();

      final dialog = find.byType(GlassDialog);
      expect(dialog, findsOneWidget);
      expect(
        find.descendant(of: dialog, matching: find.text('계정 탈퇴')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: dialog, matching: find.textContaining('정말 탈퇴하시겠습니까?')),
        findsOneWidget,
      );
      // 팝업은 유리 한 장이고, 그 안의 「탈퇴」만 주의색이다.
      final surface = tester.widget<GlassSurface>(
        find.descendant(of: dialog, matching: find.byType(GlassSurface)),
      );
      expect(surface.preset, GlassPreset.clear);
      final danger = tester.widget<FilledButton>(
        find.descendant(of: dialog, matching: find.byType(FilledButton)),
      );
      expect(
        danger.style!.backgroundColor!.resolve(const <WidgetState>{}),
        AppColors.accent,
      );

      await tester.tap(find.text('취소'));
      await tester.pumpAndSettle();
      expect(find.byType(GlassDialog), findsNothing);
      expect(session.isSignedIn, isTrue);
    });

    testWidgets('기본 정보 수정 opens a glass sheet that keeps the form', (
      tester,
    ) async {
      final session = await _signedInParent(tester);
      await tester.pumpWidget(_settings(session));
      await tester.pumpAndSettle();

      await tester.tap(find.text('기본 정보 수정'));
      await tester.pumpAndSettle();

      final sheet = find.byType(GlassSurface);
      expect(sheet, findsOneWidget);
      expect(tester.takeException(), isNull);
      expect(tester.widget<GlassSurface>(sheet).preset, GlassPreset.clear);
      expect(
        tester.widget<GlassSurface>(sheet).borderRadius,
        const BorderRadius.vertical(top: Radius.circular(26)),
      );
      // 폼은 그대로: 제목, 이름 칸, 저장 버튼.
      expect(
        find.descendant(of: sheet, matching: find.text('기본 정보 수정')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: sheet, matching: find.byType(TextField)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: sheet, matching: find.byType(FilledButton)),
        findsOneWidget,
      );
    });

    testWidgets('student code copy is the soft primary of the tab screen', (
      tester,
    ) async {
      const student = AppUser(
        id: 'student-1',
        displayName: '지민',
        profileComplete: true,
        role: AppUserRole.student,
        grade: '중1',
        studentCode: 'WY-123456',
      );
      SharedPreferences.setMockInitialValues({
        'auth_token': 'token',
        'auth_user': jsonEncode(student.toJson()),
      });
      resetAppPrefsCache();
      final session = AuthSession();
      await tester.runAsync(session.load);
      await tester.pumpWidget(_settings(session));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('번호 복사'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      final button = tester.widget<ButtonStyleButton>(
        find.ancestor(
          of: find.text('번호 복사'),
          matching: find.bySubtype<ButtonStyleButton>(),
        ),
      );
      const none = <WidgetState>{};
      expect(button.style!.backgroundColor!.resolve(none), AppColors.primarySoft);
      expect(button.style!.foregroundColor!.resolve(none), AppColors.primaryDark);
      expect(find.byType(GlassPrimaryButton), findsNothing);
    });

    testWidgets('last row scrolls above the floating tab bar', (tester) async {
      tester.view.physicalSize = const Size(390 * 3, 844 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      final session = await _signedInParent(tester);
      // 탭바 높이(64 + 16)와 홈 인디케이터를 합친 아래 여백을 흉내 낸다.
      await tester.pumpWidget(
        _settings(session, inset: const EdgeInsets.only(bottom: 114)),
      );
      await tester.pumpAndSettle();

      await tester.drag(find.byType(Scrollable).first, const Offset(0, -3000));
      await tester.pumpAndSettle();
      final last = tester.getRect(find.text('계정 탈퇴'));
      expect(last.bottom, lessThanOrEqualTo(844 - 114));
    });
  });

  group('student picker', () {
    testWidgets('switching child happens in a glass sheet', (tester) async {
      final session = await _signedInParent(tester);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: Scaffold(body: StudentPicker(authSession: session)),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('지민').first);
      await tester.pumpAndSettle();

      final sheet = find.byType(GlassSurface);
      expect(sheet, findsOneWidget);
      expect(
        find.descendant(of: sheet, matching: find.text('서연')),
        findsOneWidget,
      );

      await tester.tap(find.descendant(of: sheet, matching: find.text('서연')));
      // 선택은 prefs 저장을 기다린 뒤 시트를 닫는다.
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pumpAndSettle();
      expect(session.viewAsStudentId, 's2');
      expect(find.byType(GlassSurface), findsNothing);
    });
  });

  testWidgets('unit guide sheet is glass and keeps its guidance', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showParentUnitGuideSheet(
              context,
              unit: const CurriculumUnitProgress(
                id: 'u1',
                section: '수와 연산',
                name: '최소공배수',
                subtitle: '공배수 중 가장 작은 수',
                percent: 40,
                status: 'weak',
              ),
              profile: designReviewProfileReturning(),
            ),
            child: const Text('열기'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();

    final sheet = find.byType(GlassSurface);
    expect(sheet, findsOneWidget);
    expect(
      find.descendant(of: sheet, matching: find.text('최소공배수')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: sheet, matching: find.text('보완 필요')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: sheet, matching: find.text('학부모님이 할 수 있는 것')),
      findsOneWidget,
    );
  });

  group('signup', () {
    Widget signup({VoidCallback? onGuest}) {
      return MaterialApp(
        theme: buildAppTheme(),
        home: SignupScreen(
          apiClient: ApiClient(authSession: AuthSession()),
          oauthService: OAuthService(),
          onSignedIn: () {},
          onContinueAsGuest: onGuest,
        ),
      );
    }

    testWidgets('one glass primary, white fields, outlined secondaries', (
      tester,
    ) async {
      await tester.pumpWidget(signup(onGuest: () {}));
      await tester.pump();

      expect(find.byType(TextField), findsNWidgets(2));
      expect(find.byType(GlassPrimaryButton), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(GlassPrimaryButton),
          matching: find.text('시작하기'),
        ),
        findsOneWidget,
      );
      expect(find.widgetWithText(OutlinedButton, '게스트로 둘러보기'), findsOneWidget);
      expect(find.byType(OAuthSignInButton), findsWidgets);
      // 유리는 주 버튼 하나뿐이다.
      expect(find.byType(BackdropFilter), findsOneWidget);
    });

    testWidgets('게스트로 둘러보기 calls back', (tester) async {
      var guest = 0;
      await tester.pumpWidget(signup(onGuest: () => guest++));
      await tester.pump();
      await tester.tap(find.text('게스트로 둘러보기'));
      await tester.pump();
      expect(guest, 1);
    });
  });

  group('OAuthSignInButton', () {
    Widget button({required bool enabled, required VoidCallback onPressed}) {
      return MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(
          body: OAuthSignInButton(
            provider: OAuthProvider.kakao,
            label: '카카오로 시작하기',
            enabled: enabled,
            onPressed: onPressed,
          ),
        ),
      );
    }

    testWidgets('is a white outlined pill that taps when enabled', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(button(enabled: true, onPressed: () => taps++));
      expect(find.byType(BackdropFilter), findsNothing);
      expect(tester.getSize(find.byType(OutlinedButton)).height, 52);
      await tester.tap(find.text('카카오로 시작하기'));
      expect(taps, 1);
    });

    testWidgets('stays white and dimmed, and ignores taps, when disabled', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(button(enabled: false, onPressed: () => taps++));
      expect(tester.widget<Opacity>(find.byType(Opacity).first).opacity, 0.45);
      final style = tester.widget<OutlinedButton>(find.byType(OutlinedButton)).style!;
      expect(
        style.backgroundColor!.resolve(const {WidgetState.disabled}),
        Colors.white,
      );
      await tester.tap(find.text('카카오로 시작하기'));
      expect(taps, 0);
    });
  });

  testWidgets('parent coaching card is a white card with a soft grading box', (
    tester,
  ) async {
    final card = designReviewProfileParent().parentCoachingCard!;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(body: ParentCoachingCardWidget(card: card)),
      ),
    );
    expect(find.byType(AppCard), findsOneWidget);
    expect(find.byType(BackdropFilter), findsNothing);
    expect(find.byIcon(Icons.flag_outlined), findsOneWidget);
    final box = tester.widget<Container>(
      find.ancestor(
        of: find.byIcon(Icons.flag_outlined),
        matching: find.byType(Container),
      ).first,
    );
    expect((box.decoration! as BoxDecoration).color, AppColors.primarySoft);
  });

  testWidgets('problem review sheet is glass, draws its own handle, and closes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final problemSet = designReviewProblemSetCompact();
    final problemId = problemSet.problems.first.id;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: LoopResultScreen(
          apiClient: ApiClient(authSession: AuthSession()),
          problemSet: problemSet,
          feedback: {
            problemId: ProblemAttempt(
              id: 'att_bad',
              problemId: problemId,
              answer: '1',
              isCorrect: false,
              feedback: '다시 한 번 풀어 볼까요?',
            ),
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('풀이 보기'));
    await tester.pumpAndSettle();

    final sheet = find.byType(GlassSurface);
    expect(sheet, findsOneWidget);
    expect(tester.widget<GlassSurface>(sheet).preset, GlassPreset.clear);
    expect(
      find.descendant(of: sheet, matching: find.textContaining('문제 1번')),
      findsOneWidget,
    );
    // 손잡이는 시트 안 내용이 그린 것 하나뿐이다(40 x 4).
    expect(
      find.descendant(
        of: sheet,
        matching: find.byWidgetPredicate(
          (w) => w is Container && w.constraints?.maxWidth == 40,
        ),
      ),
      findsOneWidget,
    );

    // 닫기 버튼은 화면 낭독기에도 「닫기」로 읽힌다.
    expect(find.descendant(of: sheet, matching: find.byTooltip('닫기')), findsOneWidget);
    await tester.tap(find.descendant(of: sheet, matching: find.byIcon(Icons.close_rounded)));
    await tester.pumpAndSettle();
    expect(find.byType(GlassSurface), findsNothing);
  });

  testWidgets('relabeling a child opens a glass sheet with the name field', (
    tester,
  ) async {
    final session = await _signedInParent(tester);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: LinkedChildrenPanel(
              apiClient: ApiClient(authSession: session),
              linkedStudents: _children,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('표시 이름 변경').first);
    await tester.pumpAndSettle();

    final sheet = find.byType(GlassSurface);
    expect(sheet, findsOneWidget);
    expect(tester.widget<GlassSurface>(sheet).preset, GlassPreset.clear);
    expect(
      find.descendant(of: sheet, matching: find.byType(TextField)),
      findsOneWidget,
    );
    expect(
      find.descendant(of: sheet, matching: find.text('표시 이름 변경')),
      findsOneWidget,
    );
  });

  testWidgets('brief practice loading shows a glass card until the work ends', (
    tester,
  ) async {
    final work = Completer<int>();
    int? result;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await withBriefPracticeLoading(context, () => work.future);
            },
            child: const Text('열기'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('열기'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('문제 준비 중…'), findsOneWidget);
    expect(find.byType(Card), findsNothing);
    final surface = tester.widget<GlassSurface>(find.byType(GlassSurface));
    expect(surface.preset, GlassPreset.clear);
    expect(surface.borderRadius, BorderRadius.circular(26));

    work.complete(7);
    await tester.pumpAndSettle();
    expect(result, 7);
    expect(find.byType(GlassSurface), findsNothing);
  });

  testWidgets('asking for a new problem set confirms in a glass dialog', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: PracticeScreen(
          apiClient: ApiClient(authSession: AuthSession()),
          problemSet: designReviewProblemSetQuestion(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 풀던 기록이 있어야 확인 팝업이 뜬다.
    await tester.tap(find.byType(AppChoiceTile).first);
    await tester.pump();
    await tester.tap(find.byTooltip('문제 메뉴'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('새로운 문제받기'));
    await tester.pumpAndSettle();

    final dialog = find.byType(GlassDialog);
    expect(dialog, findsOneWidget);
    expect(
      find.descendant(of: dialog, matching: find.text('새로운 문제를 받을까요?')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: dialog, matching: find.text('계속')),
      findsOneWidget,
    );

    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();
    expect(find.byType(GlassDialog), findsNothing);
  });

  testWidgets('parent explain detail: PDF button is the soft primary and keeps its label', (
    tester,
  ) async {
    final item = designReviewProfileParent().parentWrongExplains.first;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: ParentExplainDetailScreen(
          apiClient: ApiClient(authSession: AuthSession()),
          item: item,
        ),
      ),
    );
    await tester.pump();

    await tester.scrollUntilVisible(
      find.text('유사문제 PDF 발행'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    final button = tester.widget<ButtonStyleButton>(
      find.ancestor(
        of: find.text('유사문제 PDF 발행'),
        matching: find.bySubtype<ButtonStyleButton>(),
      ),
    );
    const none = <WidgetState>{};
    expect(button.style!.backgroundColor!.resolve(none), AppColors.primarySoft);
    expect(button.style!.foregroundColor!.resolve(none), AppColors.primaryDark);
    expect(button.onPressed, isNotNull);
    expect(find.byIcon(Icons.picture_as_pdf_outlined), findsOneWidget);
    expect(find.byType(GlassPrimaryButton), findsNothing);
  });
}
