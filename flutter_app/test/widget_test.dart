import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:math_lens_tutor/main.dart';
import 'package:math_lens_tutor/services/api_client.dart';
import 'package:math_lens_tutor/services/auth_session.dart';
import 'package:math_lens_tutor/services/oauth_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('renders design review student hub', (WidgetTester tester) async {
    final authSession = AuthSession();
    await tester.pumpWidget(
      MathLensTutorApp(
        apiClient: ApiClient(authSession: authSession),
        authSession: authSession,
        oauthService: OAuthService(),
        designReviewKey: 'student_hub__first_visit',
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('우열'), findsOneWidget);
  });
}
