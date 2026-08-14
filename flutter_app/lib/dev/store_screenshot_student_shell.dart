import 'package:flutter/material.dart';

import '../models/app_models.dart';
import '../screens/student_hub_screen.dart';
import '../screens/student_progress_screen.dart';
import '../screens/student_training_screen.dart';
import '../screens/upload_screen.dart';
import '../services/api_client.dart';
import '../services/oauth_service.dart';
import '../theme/app_design_system.dart';
import '../widgets/glass.dart';
import 'design_review_data.dart';

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
    _index = widget.initialTabIndex.clamp(0, 4);
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
        demoIsGuest: widget.hubFirstVisit,
      ),
      UploadScreen(
        apiClient: widget.apiClient,
        embeddedInShell: true,
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
      const _SettingsPlaceholder(),
    ];

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GlassAtmosphere(
        child: SafeArea(
          child: IndexedStack(
            index: _index,
            children: tabs,
          ),
        ),
      ),
      bottomNavigationBar: GlassNavBar(
        child: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: '홈',
          ),
          NavigationDestination(
            icon: Icon(Icons.camera_alt_outlined),
            selectedIcon: Icon(Icons.camera_alt_rounded),
            label: '업로드',
          ),
          NavigationDestination(
            icon: Icon(Icons.edit_note_outlined),
            selectedIcon: Icon(Icons.edit_note_rounded),
            label: '훈련',
          ),
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book_rounded),
            label: '진도',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings_rounded),
            label: '설정',
          ),
        ],
      ),
      ),
    );
  }
}

class _SettingsPlaceholder extends StatelessWidget {
  const _SettingsPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        '설정',
        style: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w800,
          color: AppColors.textSub,
        ),
      ),
    );
  }
}
