import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker_android/image_picker_android.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';

import 'app_variant.dart';
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
import 'screens/lite_gate.dart';
import 'theme/app_design_system.dart';

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

String resolveStoreScreenshotKey() {
  const fromDefine = String.fromEnvironment('STORE_SCREENSHOT', defaultValue: '');
  if (fromDefine.trim().isNotEmpty) {
    return fromDefine.trim();
  }
  if (kIsWeb) {
    final q = Uri.base.queryParameters['store_screenshot'];
    if (q != null && q.trim().isNotEmpty) {
      return q.trim();
    }
  }
  return '';
}

void _configureAndroidPhotoPicker() {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
    return;
  }
  final impl = ImagePickerPlatform.instance;
  if (impl is ImagePickerAndroid) {
    impl.useAndroidPhotoPicker = true;
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _configureAndroidPhotoPicker();
  if (!isLiteApp) {
    unawaited(initializeOAuthSdk());
    unawaited(initializeMagicLinkAuth());
  }
  if (kDebugMode) {
    debugPrint('[study] variant=$appVariantHeader API baseUrl=${resolveApiBaseUrl()}');
  }

  final authSession = AuthSession();
  final apiClient = ApiClient(authSession: authSession);
  final oauthService = OAuthService();
  final designReviewKey = resolveDesignReviewKey();
  final storeScreenshotKey = resolveStoreScreenshotKey();

  runApp(
    AppRestart(
      child: MathLensTutorApp(
        apiClient: apiClient,
        authSession: authSession,
        oauthService: oauthService,
        designReviewKey: designReviewKey,
        storeScreenshotKey: storeScreenshotKey,
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
    this.storeScreenshotKey = '',
  });

  final ApiClient apiClient;
  final AuthSession authSession;
  final OAuthService oauthService;
  final String designReviewKey;
  final String storeScreenshotKey;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: appDisplayName,
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
          : storeScreenshotKey.isEmpty
              ? (isLiteApp
                  ? LiteGate(
                      apiClient: apiClient,
                      authSession: authSession,
                    )
                  : (kDebugMode
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
                        )))
              : StoreScreenshotShell(
                  screen: storeScreenshotKey,
                  apiClient: apiClient,
                  oauthService: oauthService,
                ),
    );
  }
}
