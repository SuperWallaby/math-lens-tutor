import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:math_lens_tutor/dev/design_review_data.dart';
import 'package:math_lens_tutor/screens/analysis_screen.dart';
import 'package:math_lens_tutor/screens/practice_screen.dart';
import 'package:math_lens_tutor/screens/student_training_screen.dart';
import 'package:math_lens_tutor/screens/upload_screen.dart';
import 'package:math_lens_tutor/services/api_client.dart';
import 'package:math_lens_tutor/services/app_prefs.dart';
import 'package:math_lens_tutor/services/auth_session.dart';
import 'package:math_lens_tutor/theme/app_design_system.dart';
import 'package:math_lens_tutor/widgets/app_card.dart';
import 'package:math_lens_tutor/widgets/glass.dart';
import 'package:shared_preferences/shared_preferences.dart';

ApiClient _api() => ApiClient(authSession: AuthSession());

Widget _app(Widget home) => MaterialApp(theme: buildAppTheme(), home: home);

/// 파란 유리 주 버튼은 화면 상태마다 하나만 있어야 한다.
Finder get _primaryButtons => find.byType(GlassPrimaryButton);

/// `OutlinedButton.icon`은 비공개 하위 클래스라 `find.byType`이 놓친다.
Finder _outlined(String label) => find.ancestor(
      of: find.text(label),
      matching: find.bySubtype<OutlinedButton>(),
    );

/// 긴 목록(ListView)이 아래 버튼까지 만들어지도록 아주 긴 화면을 쓴다.
void _tallPhone(WidgetTester tester) {
  tester.view.physicalSize = const Size(390 * 3, 4000 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    resetAppPrefsCache();
  });

  group('analysis result', () {
    testWidgets('info rows and cards are white; one blue glass primary', (
      tester,
    ) async {
      _tallPhone(tester);
      await tester.pumpWidget(
        _app(
          AnalysisScreen(
            apiClient: _api(),
            result: designReviewAnalyzeResultWeak(),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(AppInfoRow), findsNWidgets(2));
      expect(find.byType(AppCard), findsWidgets);
      expect(_primaryButtons, findsOneWidget);
      expect(
        find.descendant(
          of: _primaryButtons,
          matching: find.text('비슷한 문제 풀기'),
        ),
        findsOneWidget,
      );
      // 나머지 행동은 테마 기본 보조 버튼.
      expect(_outlined('홈으로'), findsOneWidget);
      expect(_outlined('유사문제 PDF로 받기'), findsOneWidget);
    });
  });

  group('practice', () {
    testWidgets('question: white choice tiles, one blue glass submit', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          PracticeScreen(
            apiClient: _api(),
            problemSet: designReviewProblemSetQuestion(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AppChoiceTile), findsNWidgets(4));
      expect(_primaryButtons, findsOneWidget);
      expect(
        find.descendant(of: _primaryButtons, matching: find.text('답안 제출')),
        findsOneWidget,
      );
      // 제출 버튼과 탭바 없는 화면의 유리 한 장 말고는 흐림이 없다.
      expect(find.byType(BackdropFilter), findsOneWidget);

      // 선택지를 누르면 선택 상태가 바뀐다 (연파랑 바탕).
      await tester.tap(find.byType(AppChoiceTile).at(2));
      await tester.pump();
      final selected = tester
          .widget<DecoratedBox>(
            find
                .descendant(
                  of: find.byType(AppChoiceTile).at(2),
                  matching: find.byType(DecoratedBox),
                )
                .first,
          )
          .decoration as BoxDecoration;
      expect(selected.color, AppColors.primarySoft);
    });

    testWidgets('review mode: one blue glass next button, full width', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          PracticeScreen(
            apiClient: _api(),
            problemSet: designReviewProblemSetQuestion(),
            reviewMode: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(_primaryButtons, findsOneWidget);
      expect(
        find.descendant(of: _primaryButtons, matching: find.text('다음 문제')),
        findsOneWidget,
      );
      expect(
        tester.getSize(_primaryButtons).width,
        tester.getSize(find.byType(AppChoiceTile).first).width,
      );
    });

    testWidgets('set complete: result button is primary only on the last problem', (
      tester,
    ) async {
      _tallPhone(tester);
      final set = designReviewProblemSet();
      expect(set.problems.length, greaterThanOrEqualTo(2));
      final feedback = {
        for (final p in set.problems) p.id: designReviewAttemptCorrect(),
      };

      // 중간 문제: 「다음 문제」가 주 버튼, 「세트 결과 보기」는 보조.
      await tester.pumpWidget(
        _app(
          PracticeScreen(
            apiClient: _api(),
            problemSet: set,
            demoInitialIndex: 0,
            demoFeedback: feedback,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(_primaryButtons, findsOneWidget);
      expect(
        find.descendant(of: _primaryButtons, matching: find.text('다음 문제')),
        findsOneWidget,
      );
      expect(_outlined('세트 결과 보기'), findsOneWidget);

      // 마지막 문제: 「세트 결과 보기」가 주 버튼.
      await tester.pumpWidget(
        _app(
          PracticeScreen(
            key: const ValueKey('last'),
            apiClient: _api(),
            problemSet: set,
            demoInitialIndex: set.problems.length - 1,
            demoFeedback: feedback,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(_primaryButtons, findsOneWidget);
      expect(
        find.descendant(of: _primaryButtons, matching: find.text('세트 결과 보기')),
        findsOneWidget,
      );
      expect(find.bySubtype<OutlinedButton>(), findsNothing);
    });
  });

  group('upload', () {
    testWidgets('analyze button is the one blue glass primary, disabled until a photo',
        (tester) async {
      await tester.pumpWidget(_app(UploadScreen(apiClient: _api())));
      await tester.pump();

      expect(_primaryButtons, findsOneWidget);
      final button = tester.widget<GlassPrimaryButton>(_primaryButtons);
      expect(button.label, '분석하고 유사 문제 생성');
      expect(button.onPressed, isNull);
      expect(find.byType(FilledButton), findsNothing);
      expect(find.bySubtype<OutlinedButton>(), findsOneWidget);
    });
  });

  group('training tab', () {
    testWidgets('review button is the soft tab button, not a blue fill', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          Scaffold(
            body: StudentTrainingScreen(
              apiClient: _api(),
              demoProfile: designReviewProfileReturning(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, '5문제 세트로 복습'),
      );
      expect(button.style!.backgroundColor!.resolve({}), AppColors.primarySoft);
      expect(button.style!.foregroundColor!.resolve({}), AppColors.primaryDark);
      expect(_primaryButtons, findsNothing);
    });
  });
}
