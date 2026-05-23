import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'dev/store_screenshot_shell.dart';
import 'services/api_base_url.dart';
import 'services/api_client.dart';
import 'services/auth_session.dart';
import 'services/oauth_service.dart';
import 'screens/auth_gate.dart';

const _storeScreenshot = String.fromEnvironment(
  'STORE_SCREENSHOT',
  defaultValue: '',
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeOAuthSdk();
  if (kDebugMode) {
    debugPrint('[study] API baseUrl=${resolveApiBaseUrl()}');
  }

  final authSession = AuthSession();
  final apiClient = ApiClient(authSession: authSession);
  final oauthService = OAuthService();

  runApp(
    MathLensTutorApp(
      apiClient: apiClient,
      authSession: authSession,
      oauthService: oauthService,
    ),
  );
}

class MathLensTutorApp extends StatelessWidget {
  const MathLensTutorApp({
    super.key,
    required this.apiClient,
    required this.authSession,
    required this.oauthService,
  });

  final ApiClient apiClient;
  final AuthSession authSession;
  final OAuthService oauthService;

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
        return MediaQuery(
          data: mq.copyWith(textScaler: TextScaler.linear(scale)),
          child: child,
        );
      },
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2563EB),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF020617),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF020617),
          foregroundColor: Colors.white,
          centerTitle: false,
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ),
      home: _storeScreenshot.isEmpty
          ? AuthGate(
              apiClient: apiClient,
              authSession: authSession,
              oauthService: oauthService,
            )
          : StoreScreenshotShell(
              screen: _storeScreenshot,
              apiClient: apiClient,
            ),
    );
  }
}
