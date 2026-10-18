import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:math_lens_tutor/screens/auth_gate.dart';
import 'package:math_lens_tutor/screens/signup_screen.dart';
import 'package:math_lens_tutor/services/api_client.dart';
import 'package:math_lens_tutor/services/app_prefs.dart';
import 'package:math_lens_tutor/services/auth_session.dart';
import 'package:math_lens_tutor/services/oauth_service.dart';
import 'package:math_lens_tutor/theme/app_design_system.dart';
import 'package:math_lens_tutor/widgets/oauth_sign_in_button.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 로그인 링크 발송만 기록하는 API — 네트워크에 나가지 않는다.
class _LinkApi extends ApiClient {
  _LinkApi(AuthSession session) : super(authSession: session);

  final sentTo = <String>[];

  @override
  Future<MagicLinkSendResponse> sendMagicLink(
    String email, {
    bool signupOnly = false,
  }) async {
    sentTo.add(email);
    return const MagicLinkSendResponse(message: 'sent');
  }
}

/// 로그아웃 상태로 앱 첫 화면을 띄우고 스플래시가 끝날 때까지 돌린다.
Future<({_LinkApi api, AuthSession session})> _pumpSignedOut(
  WidgetTester tester,
) async {
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  final session = AuthSession();
  final api = _LinkApi(session);
  await tester.pumpWidget(
    MaterialApp(
      theme: buildAppTheme(),
      home: AuthGate(
        apiClient: api,
        authSession: session,
        oauthService: OAuthService(),
      ),
    ),
  );
  // 스플래시 최소 시간(0.9초)을 넘긴다.
  await tester.pump(const Duration(seconds: 1));
  await tester.pump();
  return (api: api, session: session);
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    resetAppPrefsCache();
  });

  group('signed-out start', () {
    testWidgets('shows the social sign-in buttons', (tester) async {
      await _pumpSignedOut(tester);

      expect(find.byType(SignupScreen), findsOneWidget);
      expect(find.byType(OAuthSignInButton), findsWidgets);
    });

    testWidgets('시작하기 sends a login link instead of entering as guest', (
      tester,
    ) async {
      final (:api, :session) = await _pumpSignedOut(tester);

      await tester.enterText(find.byType(TextField).first, 'jimin@example.com');
      await tester.tap(find.text('시작하기'));
      await tester.pump();

      expect(session.isGuest, isFalse);
      expect(api.sentTo, ['jimin@example.com']);
      expect(find.text('메일함을 확인해 주세요'), findsOneWidget);
    });
  });
}
