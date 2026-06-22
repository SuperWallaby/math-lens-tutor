import 'package:flutter/material.dart';

import '../screens/analysis_screen.dart';
import '../screens/dashboard_screen.dart';
import '../screens/student_hub_screen.dart';
import '../screens/practice_screen.dart';
import '../screens/upload_screen.dart';
import '../services/api_client.dart';
import '../services/oauth_service.dart';
import 'store_screenshot_data.dart';

/// `--dart-define=STORE_SCREENSHOT=home|upload|analysis|practice|dashboard`
class StoreScreenshotShell extends StatelessWidget {
  const StoreScreenshotShell({
    super.key,
    required this.screen,
    required this.apiClient,
    required this.oauthService,
  });

  final String screen;
  final ApiClient apiClient;
  final OAuthService oauthService;

  @override
  Widget build(BuildContext context) {
    switch (screen) {
      case 'home':
        return StudentHubScreen(
          apiClient: apiClient,
          oauthService: oauthService,
        );
      case 'upload':
        return UploadScreen(apiClient: apiClient);
      case 'analysis':
        return AnalysisScreen(
          apiClient: apiClient,
          result: storeScreenshotAnalyzeResult(),
        );
      case 'practice':
        return PracticeScreen(
          apiClient: apiClient,
          problemSet: storeScreenshotAnalyzeResult().problemSet,
        );
      case 'dashboard':
        return DashboardScreen(
          apiClient: apiClient,
          demoInsight: storeScreenshotLearningInsight(),
        );
      default:
        return StudentHubScreen(
          apiClient: apiClient,
          oauthService: oauthService,
        );
    }
  }
}
