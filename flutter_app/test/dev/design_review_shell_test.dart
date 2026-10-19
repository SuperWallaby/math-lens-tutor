import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:math_lens_tutor/dev/design_review_data.dart';
import 'package:math_lens_tutor/dev/design_review_shell.dart';
import 'package:math_lens_tutor/services/api_client.dart';
import 'package:math_lens_tutor/services/app_prefs.dart';
import 'package:math_lens_tutor/services/auth_session.dart';
import 'package:math_lens_tutor/services/oauth_service.dart';
import 'package:math_lens_tutor/widgets/learning_profile_widgets.dart';
import 'package:math_lens_tutor/widgets/page_stage.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _shell(String key) {
  return MaterialApp(
    home: Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(padding: const EdgeInsets.only(top: 47)),
        child: DesignReviewShell(
          reviewKey: key,
          apiClient: ApiClient(authSession: AuthSession()),
          oauthService: OAuthService(),
        ),
      ),
    ),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    resetAppPrefsCache();
  });

  test('the training feed key is listed for capture', () {
    expect(designReviewCaptureKeys, contains('student_training__feed'));
  });

  for (final key in [
    'student_training__feed',
    'student_training__empty',
    'student_progress__grade_m1',
  ]) {
    testWidgets('$key: the stage reaches the top edge', (tester) async {
      await tester.pumpWidget(_shell(key));
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(find.byType(PageStage)).dy, 0);
    });
  }

  testWidgets('student_training__feed shows the feed list', (tester) async {
    await tester.pumpWidget(_shell('student_training__feed'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(SectionLabel, '풀 문제'), findsOneWidget);
  });
}
