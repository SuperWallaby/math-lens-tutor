import 'package:flutter/material.dart';

import '../models/app_models.dart';
import '../screens/settings_screen.dart';
import '../screens/student_hub_screen.dart';
import '../screens/student_progress_screen.dart';
import '../screens/student_training_screen.dart';
import '../services/api_client.dart';
import '../services/oauth_service.dart';
import '../widgets/glass.dart';
import 'design_review_data.dart';
import '../theme/app_icons.dart';

/// 학생 AppShell + 하단 탭 — 스토어 스크린샷용.
class StoreScreenshotStudentShell extends StatefulWidget {
  const StoreScreenshotStudentShell({
    super.key,
    required this.apiClient,
    required this.oauthService,
    required this.initialTabIndex,
    this.hubFirstVisit = false,
    this.progressProfile,
    this.progressGradeTab,
  });

  final ApiClient apiClient;
  final OAuthService oauthService;
  final int initialTabIndex;
  final bool hubFirstVisit;
  final LearningProfile? progressProfile;
  final int? progressGradeTab;

  @override
  State<StoreScreenshotStudentShell> createState() =>
      _StoreScreenshotStudentShellState();
}

class _StoreScreenshotStudentShellState
    extends State<StoreScreenshotStudentShell> {
  late int _index;

  @override
  void initState() {
    super.initState();
    widget.apiClient.authSession.useStoreScreenshotDemoStudent();
    _index = widget.initialTabIndex.clamp(0, 3);
  }

  LearningProfile get _returningProfile => designReviewProfileReturning();

  @override
  Widget build(BuildContext context) {
    final hubProfile = widget.hubFirstVisit
        ? designReviewProfileFirstVisit()
        : _returningProfile;
    final hubSubmissions = widget.hubFirstVisit
        ? designReviewSubmissionsEmpty()
        : designReviewSubmissionsRecent();
    final progressProfile =
        widget.progressProfile ?? designReviewProfileGradeM1();
    final progressTab = widget.progressGradeTab ?? 3;

    final tabs = [
      StudentHubScreen(
        apiClient: widget.apiClient,
        oauthService: widget.oauthService,
        demoProfile: hubProfile,
        demoSubmissions: hubSubmissions,
        demoIsGuest: false,
      ),
      StudentTrainingScreen(
        apiClient: widget.apiClient,
        demoProfile: _returningProfile,
        demoFeed: designReviewTrainingFeed(),
      ),
      StudentProgressScreen(
        apiClient: widget.apiClient,
        demoProfile: progressProfile,
        demoInitialGradeTab: progressTab,
      ),
      SettingsScreen(
        apiClient: widget.apiClient,
        oauthService: widget.oauthService,
      ),
    ];

    return Scaffold(
      extendBody: true,
      backgroundColor: Colors.transparent,
      body: GlassAtmosphere(
        child: IndexedStack(index: _index, children: tabs),
      ),
      bottomNavigationBar: GlassTabBar(
        selectedIndex: _index,
        onSelected: (value) => setState(() => _index = value),
        onCenterAction: () {},
        labels: const ['홈', '훈련', '성장', '설정'],
        icons: const [
          AppIcons.home,
          AppIcons.training,
          AppIcons.growth,
          AppIcons.settings,
        ],
        selectedIcons: const [
          AppIcons.homeFill,
          AppIcons.trainingFill,
          AppIcons.growthFill,
          AppIcons.settingsFill,
        ],
      ),
    );
  }
}
