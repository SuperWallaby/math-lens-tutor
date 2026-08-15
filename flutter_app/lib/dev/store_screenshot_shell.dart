import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../screens/analysis_screen.dart';
import '../screens/parent_explain_screen.dart';
import '../screens/parent_screens.dart';
import '../screens/practice_screen.dart';
import '../screens/signup_screen.dart';
import '../services/api_client.dart';
import '../services/oauth_service.dart';
import '../widgets/glass.dart';
import '../widgets/pin_html_overlay.dart';
import 'design_review_data.dart';
import 'store_screenshot_student_shell.dart';

/// `--dart-define=STORE_SCREENSHOT=...` or web `/?store_screenshot=hub-returning`
class StoreScreenshotShell extends StatefulWidget {
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
  State<StoreScreenshotShell> createState() => _StoreScreenshotShellState();
}

class _StoreScreenshotShellState extends State<StoreScreenshotShell> {
  String? _next;

  void _openHome() => setState(() => _next = 'hub-returning');

  String? _pinHtmlScreen(String mode) {
    return switch (mode) {
      'login' || 'signup' => 'login',
      'hub-first' || 'hub-returning' || 'home' => 'home',
      'practice-question' || 'practice' => 'practice',
      'analysis-weak' || 'analysis-ok' || 'analysis' => 'analysis',
      _ => null,
    };
  }

  void _onPinAction(String action) {
    final next = switch (action) {
      'home' => 'hub-returning',
      'practice' => 'practice-question',
      'analysis' => 'analysis-weak',
      'login' => 'login',
      _ => null,
    };
    if (next == null) return;
    setState(() => _next = next);
  }

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
    final apiClient = widget.apiClient;
    final oauthService = widget.oauthService;
    final mode = _normalizeMode(_next ?? widget.screen);
    final pinScreen = kIsWeb ? _pinHtmlScreen(mode) : null;
    if (pinScreen != null) {
      return PinHtmlOverlay(screen: pinScreen, onAction: _onPinAction);
    }

    switch (mode) {
      case 'login':
      case 'signup':
        return SignupScreen(
          apiClient: apiClient,
          oauthService: oauthService,
          onSignedIn: _openHome,
          onContinueAsGuest: _openHome,
          matchPinPreview: true,
        );
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
            matchPinPreview: true,
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
            matchPinPreview: true,
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
        return _fullScreen(
          ParentHomeScreen(
            apiClient: apiClient,
            demoProfile: designReviewProfileParent(),
          ),
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
