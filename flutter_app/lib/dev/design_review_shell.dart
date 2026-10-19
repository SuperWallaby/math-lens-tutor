import 'package:flutter/material.dart';

import '../screens/analysis_screen.dart';
import '../screens/practice_screen.dart';
import '../screens/student_hub_screen.dart';
import '../screens/student_progress_screen.dart';
import '../screens/student_training_screen.dart';
import '../screens/upload_screen.dart';
import '../services/api_client.dart';
import '../services/oauth_service.dart';
import '../theme/app_design_system.dart';
import 'design_review_data.dart';

/// `DESIGN_REVIEW=screenId__state` or `/?design_review=screenId__state` (web).
class DesignReviewShell extends StatelessWidget {
  const DesignReviewShell({
    super.key,
    required this.reviewKey,
    required this.apiClient,
    required this.oauthService,
  });

  final String reviewKey;
  final ApiClient apiClient;
  final OAuthService oauthService;

  Widget _fullBleed(Widget body) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: body,
    );
  }

  @override
  Widget build(BuildContext context) {
    final parsed = parseDesignReviewKey(reviewKey);
    switch (parsed.screen) {
      case 'student_hub':
        // 파란 무대가 위쪽 안전 영역까지 채우므로 SafeArea로 감싸지 않는다.
        return Scaffold(
          backgroundColor: AppColors.background,
          body: _studentHub(parsed.state),
        );
      case 'upload':
        return _upload(parsed.state);
      case 'analysis':
        return _analysis(parsed.state);
      case 'practice':
        return _practice(parsed.state);
      // 탭 화면도 파란 무대가 위쪽 안전 영역까지 채우므로 SafeArea로 감싸지 않는다.
      case 'student_progress':
        return _fullBleed(_studentProgress(parsed.state));
      case 'student_training':
        return _fullBleed(_studentTraining(parsed.state));
      default:
        return Scaffold(
          body: Center(
            child: Text('Unknown design review key: $reviewKey'),
          ),
        );
    }
  }

  Widget _upload(String state) {
    if (state == 'analyzing') {
      return AnalysisScreen(
        apiClient: apiClient,
        demoLoading: true,
      );
    }
    return UploadScreen(apiClient: apiClient);
  }

  Widget _studentHub(String state) {
    final user = designReviewUser();
    final today = designReviewToday;
    switch (state) {
      case 'returning':
        return StudentHubScreen(
          apiClient: apiClient,
          oauthService: oauthService,
          demoProfile: designReviewProfileReturning(),
          demoSubmissions: designReviewSubmissionsRecent(),
          demoIsGuest: false,
          demoUser: user,
          demoToday: today,
        );
      case 'guest':
        return StudentHubScreen(
          apiClient: apiClient,
          oauthService: oauthService,
          demoProfile: designReviewProfileReturning(),
          demoSubmissions: designReviewSubmissionsRecent(),
          demoIsGuest: true,
          demoUser: user,
          demoToday: today,
        );
      case 'first_visit':
      default:
        return StudentHubScreen(
          apiClient: apiClient,
          oauthService: oauthService,
          demoProfile: designReviewProfileFirstVisit(),
          demoSubmissions: designReviewSubmissionsEmpty(),
          demoIsGuest: false,
          demoUser: user,
          demoToday: today,
        );
    }
  }

  Widget _analysis(String state) {
    switch (state) {
      case 'analyzing':
        return AnalysisScreen(
          apiClient: apiClient,
          demoLoading: true,
        );
      case 'result_ok':
        return AnalysisScreen(
          apiClient: apiClient,
          result: designReviewAnalyzeResultOk(),
        );
      case 'result_weak':
      default:
        return AnalysisScreen(
          apiClient: apiClient,
          result: designReviewAnalyzeResultWeak(),
        );
    }
  }

  Widget _practice(String state) {
    final set = switch (state) {
      'question' => designReviewProblemSetQuestion(),
      'trig_graph' => designReviewProblemSetTrigGraph(),
      _ => designReviewProblemSet(),
    };
    switch (state) {
      case 'feedback_correct':
        return PracticeScreen(
          apiClient: apiClient,
          problemSet: designReviewProblemSetCompact(),
          demoInitialIndex: 0,
          demoFeedback: {'p1': designReviewAttemptCorrect()},
          demoAnswers: {'p1': '2'},
          reviewMode: true,
        );
      case 'feedback_wrong':
        return PracticeScreen(
          apiClient: apiClient,
          problemSet: designReviewProblemSetCompact(),
          demoInitialIndex: 0,
          demoFeedback: {'p1': designReviewAttemptWrong()},
          demoAnswers: {'p1': '1'},
          reviewMode: true,
        );
      case 'question':
      default:
        return PracticeScreen(
          apiClient: apiClient,
          problemSet: set,
          reviewMode: true,
        );
    }
  }

  Widget _studentTraining(String state) {
    switch (state) {
      case 'feed':
        return StudentTrainingScreen(
          apiClient: apiClient,
          demoProfile: designReviewProfileReturning(),
          demoFeed: designReviewTrainingFeed(),
        );
      case 'empty':
      default:
        return StudentTrainingScreen(
          apiClient: apiClient,
          demoProfile: designReviewProfileFirstVisit(),
          demoFeed: designReviewTrainingFeedEmpty(),
        );
    }
  }

  Widget _studentProgress(String state) {
    switch (state) {
      case 'empty':
        return StudentProgressScreen(
          apiClient: apiClient,
          demoProfile: designReviewProfileFirstVisit(),
          demoInitialGradeTab: 3,
        );
      case 'grade_e12':
        return StudentProgressScreen(
          apiClient: apiClient,
          demoProfile: designReviewProfileGradeE12(),
          demoInitialGradeTab: 0,
        );
      case 'chain_warning':
        return StudentProgressScreen(
          apiClient: apiClient,
          demoProfile: designReviewProfileChainWarning(),
          demoInitialGradeTab: 3,
        );
      case 'grade_m1':
      default:
        return StudentProgressScreen(
          apiClient: apiClient,
          demoProfile: designReviewProfileGradeM1(),
          demoInitialGradeTab: 3,
        );
    }
  }
}
