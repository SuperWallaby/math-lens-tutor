import 'package:flutter/material.dart';

import '../screens/analysis_screen.dart';
import '../screens/parent_explain_screen.dart';
import '../screens/parent_screens.dart';
import '../screens/practice_screen.dart';
import '../services/api_client.dart';
import '../services/oauth_service.dart';
import '../theme/app_design_system.dart';
import '../widgets/glass.dart';
import 'design_review_data.dart';
import 'store_screenshot_student_shell.dart';

/// `--dart-define=STORE_SCREENSHOT=...` or web `/?store_screenshot=hub-returning`
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

  Widget _fullScreen(Widget child) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GlassAtmosphere(
        child: SafeArea(child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mode = _normalizeMode(screen);

    switch (mode) {
      case 'hub-first':
        return StoreScreenshotStudentShell(
          apiClient: apiClient,
          oauthService: oauthService,
          initialTabIndex: 0,
          hubFirstVisit: true,
        );
      case 'hub-returning':
      case 'home':
        return StoreScreenshotStudentShell(
          apiClient: apiClient,
          oauthService: oauthService,
          initialTabIndex: 0,
        );
      case 'tab-upload':
      case 'upload':
        return StoreScreenshotStudentShell(
          apiClient: apiClient,
          oauthService: oauthService,
          initialTabIndex: 1,
        );
      case 'tab-training':
        return StoreScreenshotStudentShell(
          apiClient: apiClient,
          oauthService: oauthService,
          initialTabIndex: 2,
        );
      case 'tab-progress':
        return StoreScreenshotStudentShell(
          apiClient: apiClient,
          oauthService: oauthService,
          initialTabIndex: 3,
          progressProfile: designReviewProfileGradeM1(),
          progressGradeTab: 3,
        );
      case 'tab-progress-warning':
        return StoreScreenshotStudentShell(
          apiClient: apiClient,
          oauthService: oauthService,
          initialTabIndex: 3,
          progressProfile: designReviewProfileChainWarning(),
          progressGradeTab: 3,
        );
      case 'tab-progress-e12':
        return StoreScreenshotStudentShell(
          apiClient: apiClient,
          oauthService: oauthService,
          initialTabIndex: 3,
          progressProfile: designReviewProfileGradeE12(),
          progressGradeTab: 0,
        );
      case 'analysis-analyzing':
        return _fullScreen(
          AnalysisScreen(apiClient: apiClient, demoLoading: true),
        );
      case 'analysis-weak':
        return _fullScreen(
          AnalysisScreen(
            apiClient: apiClient,
            result: designReviewAnalyzeResultWeak(),
          ),
        );
      case 'analysis-ok':
      case 'analysis':
        return _fullScreen(
          AnalysisScreen(
            apiClient: apiClient,
            result: designReviewAnalyzeResultOk(),
          ),
        );
      case 'practice-question':
      case 'practice':
        return _fullScreen(
          PracticeScreen(
            apiClient: apiClient,
            problemSet: designReviewProblemSetQuestion(),
            demoAnswers: const {'slope_p1': '2'},
            reviewMode: true,
          ),
        );
      case 'practice-correct':
        return _fullScreen(
          PracticeScreen(
            apiClient: apiClient,
            problemSet: designReviewProblemSetCompact(),
            demoInitialIndex: 0,
            demoFeedback: {'p_seq': designReviewAttemptCorrect()},
            demoAnswers: {'p_seq': '6'},
            reviewMode: true,
          ),
        );
      case 'practice-wrong':
        return _fullScreen(
          PracticeScreen(
            apiClient: apiClient,
            problemSet: designReviewProblemSetCompact(),
            demoInitialIndex: 0,
            demoFeedback: {'p_seq': designReviewAttemptWrong()},
            demoAnswers: {'p_seq': '1'},
            reviewMode: true,
          ),
        );
      case 'parent-home':
        return ParentHomeScreen(
          apiClient: apiClient,
          demoProfile: designReviewProfileParent(),
        );
      case 'parent-explain':
        return ParentExplainScreen(
          apiClient: apiClient,
          demoProfile: designReviewProfileParent(),
        );
      case 'dashboard':
        return _fullScreen(
          ParentHomeScreen(
            apiClient: apiClient,
            demoProfile: designReviewProfileParent(),
          ),
        );
      default:
        return StoreScreenshotStudentShell(
          apiClient: apiClient,
          oauthService: oauthService,
          initialTabIndex: 0,
        );
    }
  }

  String _normalizeMode(String raw) => raw.trim().toLowerCase();
}
