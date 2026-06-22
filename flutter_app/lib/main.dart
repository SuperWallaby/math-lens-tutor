import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'dev/app_restart.dart';
import 'dev/design_review_shell.dart';
import 'dev/dev_menu_overlay.dart';
import 'dev/store_screenshot_shell.dart';
import 'services/api_base_url.dart';
import 'services/api_client.dart';
import 'services/auth_session.dart';
import 'services/magic_link_auth.dart';
import 'services/oauth_service.dart';
import 'screens/auth_gate.dart';
import 'theme/app_design_system.dart';

const _storeScreenshot = String.fromEnvironment(
  'STORE_SCREENSHOT',
  defaultValue: '',
);

String resolveDesignReviewKey() {
  const fromDefine = String.fromEnvironment('DESIGN_REVIEW', defaultValue: '');
  if (fromDefine.trim().isNotEmpty) {
    return fromDefine.trim();
  }
  if (kIsWeb) {
    final q = Uri.base.queryParameters['design_review'];
    if (q != null && q.trim().isNotEmpty) {
      return q.trim();
    }
  }
  return '';
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  unawaited(initializeOAuthSdk());
  unawaited(initializeMagicLinkAuth());
  if (kDebugMode) {
    debugPrint('[study] API baseUrl=${resolveApiBaseUrl()}');
  }

  final authSession = AuthSession();
  final apiClient = ApiClient(authSession: authSession);
  final oauthService = OAuthService();
  final designReviewKey = resolveDesignReviewKey();

  runApp(
    AppRestart(
      child: MathLensTutorApp(
        apiClient: apiClient,
        authSession: authSession,
        oauthService: oauthService,
        designReviewKey: designReviewKey,
      ),
    ),
  );
}

class MathLensTutorApp extends StatelessWidget {
  const MathLensTutorApp({
    super.key,
    required this.apiClient,
    required this.authSession,
    required this.oauthService,
    this.designReviewKey = '',
  });

  final ApiClient apiClient;
  final AuthSession authSession;
  final OAuthService oauthService;
  final String designReviewKey;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '우열',
      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        if (child == null) {
          return const SizedBox.shrink();
        }
        final mq = MediaQuery.of(context);
        final scale = mq.size.shortestSide >= 600 ? 1.06 : 1.0;
        Widget wrapped = MediaQuery(
          data: mq.copyWith(textScaler: TextScaler.linear(scale)),
          child: child,
        );
        return wrapped;
      },
      theme: buildAppTheme(),
      home: designReviewKey.isNotEmpty
          ? DesignReviewShell(
              reviewKey: designReviewKey,
              apiClient: apiClient,
              oauthService: oauthService,
            )
          : _storeScreenshot.isEmpty
              ? (kDebugMode
                  ? DevMenuOverlay(
                      apiClient: apiClient,
                      authSession: authSession,
                      child: AuthGate(
                        apiClient: apiClient,
                        authSession: authSession,
                        oauthService: oauthService,
                      ),
                    )
                  : AuthGate(
                      apiClient: apiClient,
                      authSession: authSession,
                      oauthService: oauthService,
                    ))
              : StoreScreenshotShell(
                  screen: _storeScreenshot,
                  apiClient: apiClient,
                  oauthService: oauthService,
                ),
    );
  }
}
