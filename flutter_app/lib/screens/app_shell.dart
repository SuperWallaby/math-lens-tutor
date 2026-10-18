import 'package:flutter/material.dart';

import '../models/app_models.dart';
import '../services/api_client.dart';
import '../services/oauth_service.dart';
import '../widgets/brand_splash_view.dart';
import '../widgets/glass.dart';
import 'onboarding_screen.dart';
import 'parent_explain_screen.dart';
import 'parent_screens.dart';
import 'settings_screen.dart';
import 'student_hub_screen.dart';
import 'student_progress_screen.dart';
import 'student_training_screen.dart';
import 'teacher_screens.dart';
import 'upload_screen.dart';
import '../theme/app_icons.dart';

/// 학부모·교사가 아니면 역할이 비어 있어도 학생 탭을 쓴다(`_tabsFor`의 `default:`).
/// 카메라·배지·새로고침도 같은 기준이어야 학생 탭에서 사진을 올릴 수 있다.
bool _isStudentShell(AppUserRole? role) =>
    role != AppUserRole.parent && role != AppUserRole.teacher;

class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    required this.apiClient,
    required this.oauthService,
  });

  final ApiClient apiClient;
  final OAuthService oauthService;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;
  final _studentHubKey = GlobalKey<StudentHubScreenState>();
  final _studentTrainingKey = GlobalKey<StudentTrainingScreenState>();
  final _studentProgressKey = GlobalKey<StudentProgressScreenState>();

  static const _studentHomeTabIndex = 0;
  static const _studentTrainingTabIndex = 1;
  static const _studentProgressTabIndex = 2;

  /// 하단 네비 맞춤훈련 탭 배지 — 준비된 맞춤 문제 수. 탭을 한 번 열면 사라진다.
  int _trainingBadgeCount = 0;
  bool _trainingTabSeen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final user = widget.apiClient.authSession.user;
      if (user != null) {
        widget.apiClient.getLearningProfile(
          scope: LearningProfileScope.summary,
        );
        if (_isStudentShell(user.role)) {
          _loadTrainingBadge();
        }
      }
    });
  }

  Future<void> _loadTrainingBadge() async {
    if (_trainingTabSeen) return;
    try {
      final feed = await widget.apiClient.getTrainingFeed();
      if (!mounted || _trainingTabSeen) return;
      setState(() => _trainingBadgeCount = feed.items.length);
    } catch (_) {
      // 배지는 부가 정보이므로 실패는 조용히 무시한다.
    }
  }

  /// 가운데 카메라: 업로드 흐름을 전체 화면으로 연다(탭 전환이 아니다).
  Future<void> _openUpload() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => UploadScreen(apiClient: widget.apiClient),
      ),
    );
    if (!mounted) return;
    _studentHubKey.currentState?.refreshFromTab(forceRefresh: true);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.apiClient.authSession,
      builder: (context, _) {
        final user = widget.apiClient.authSession.user;
        if (user == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final isStudentShell = _isStudentShell(user.role);
        final tabs = _tabsFor(user.role);
        final safeIndex = _index.clamp(0, tabs.length - 1);
        if (safeIndex != _index) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _index = safeIndex);
          });
        }

        return Scaffold(
          extendBody: true,
          backgroundColor: Colors.transparent,
          body: GlassAtmosphere(
            child: IndexedStack(
              index: safeIndex,
              children: tabs.map((tab) => tab.screen).toList(),
            ),
          ),
          bottomNavigationBar: GlassTabBar(
            labels: [for (final tab in tabs) tab.label],
            icons: [for (final tab in tabs) tab.icon],
            selectedIcons: [for (final tab in tabs) tab.selectedIcon],
            selectedIndex: safeIndex,
            onCenterAction: isStudentShell ? _openUpload : null,
            badgeIndex: isStudentShell ? _studentTrainingTabIndex : null,
            badgeCount:
                _showTrainingBadge(isStudentShell, _studentTrainingTabIndex)
                ? _trainingBadgeCount
                : 0,
            onSelected: (value) {
              setState(() => _index = value);
              if (isStudentShell) {
                if (value == _studentHomeTabIndex) {
                  _studentHubKey.currentState?.refreshFromTab();
                } else if (value == _studentTrainingTabIndex) {
                  _studentTrainingKey.currentState?.refreshFromTab();
                  if (_trainingBadgeCount > 0 || !_trainingTabSeen) {
                    setState(() {
                      _trainingBadgeCount = 0;
                      _trainingTabSeen = true;
                    });
                  }
                } else if (value == _studentProgressTabIndex) {
                  _studentProgressKey.currentState?.refreshFromTab();
                }
              }
            },
          ),
        );
      },
    );
  }

  bool _showTrainingBadge(bool isStudentShell, int tabIndex) {
    return isStudentShell &&
        tabIndex == _studentTrainingTabIndex &&
        !_trainingTabSeen &&
        _trainingBadgeCount > 0;
  }

  List<_ShellTab> _tabsFor(AppUserRole? role) {
    switch (role) {
      case AppUserRole.parent:
        return [
          _ShellTab(
            label: '홈',
            icon: AppIcons.home,
            selectedIcon: AppIcons.homeFill,
            screen: ParentHomeScreen(apiClient: widget.apiClient),
          ),
          _ShellTab(
            label: '설명',
            icon: AppIcons.book,
            selectedIcon: AppIcons.bookFill,
            screen: ParentExplainScreen(apiClient: widget.apiClient),
          ),
          _ShellTab(
            label: '이번 주',
            icon: AppIcons.week,
            selectedIcon: AppIcons.weekFill,
            screen: ParentReportScreen(apiClient: widget.apiClient),
          ),
          _ShellTab(
            label: '진도',
            icon: AppIcons.route,
            selectedIcon: AppIcons.routeFill,
            screen: StudentProgressScreen(
              apiClient: widget.apiClient,
              viewAsGuardian: true,
            ),
          ),
          _ShellTab(
            label: '설정',
            icon: AppIcons.settings,
            selectedIcon: AppIcons.settingsFill,
            screen: SettingsScreen(
              apiClient: widget.apiClient,
              oauthService: widget.oauthService,
            ),
          ),
        ];
      case AppUserRole.teacher:
        return [
          _ShellTab(
            label: '홈',
            icon: AppIcons.home,
            selectedIcon: AppIcons.homeFill,
            screen: TeacherHomeScreen(apiClient: widget.apiClient),
          ),
          _ShellTab(
            label: '학생',
            icon: AppIcons.person,
            selectedIcon: AppIcons.personFill,
            screen: TeacherStudentDetailScreen(apiClient: widget.apiClient),
          ),
          _ShellTab(
            label: '반진도',
            icon: AppIcons.group,
            selectedIcon: AppIcons.groupFill,
            screen: TeacherClassProgressScreen(apiClient: widget.apiClient),
          ),
          _ShellTab(
            label: '설정',
            icon: AppIcons.settings,
            selectedIcon: AppIcons.settingsFill,
            screen: SettingsScreen(
              apiClient: widget.apiClient,
              oauthService: widget.oauthService,
            ),
          ),
        ];
      case AppUserRole.student:
      default:
        return [
          _ShellTab(
            label: '홈',
            icon: AppIcons.home,
            selectedIcon: AppIcons.homeFill,
            screen: StudentHubScreen(
              key: _studentHubKey,
              apiClient: widget.apiClient,
              oauthService: widget.oauthService,
            ),
          ),
          _ShellTab(
            label: '훈련',
            icon: AppIcons.training,
            selectedIcon: AppIcons.trainingFill,
            screen: StudentTrainingScreen(
              key: _studentTrainingKey,
              apiClient: widget.apiClient,
            ),
          ),
          _ShellTab(
            label: '성장',
            icon: AppIcons.growth,
            selectedIcon: AppIcons.growthFill,
            screen: StudentProgressScreen(
              key: _studentProgressKey,
              apiClient: widget.apiClient,
            ),
          ),
          _ShellTab(
            label: '설정',
            icon: AppIcons.settings,
            selectedIcon: AppIcons.settingsFill,
            screen: SettingsScreen(
              apiClient: widget.apiClient,
              oauthService: widget.oauthService,
            ),
          ),
        ];
    }
  }
}

class _ShellTab {
  const _ShellTab({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.screen,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final Widget screen;
}

class AppBootstrap extends StatefulWidget {
  const AppBootstrap({
    super.key,
    required this.apiClient,
    required this.oauthService,
  });

  final ApiClient apiClient;
  final OAuthService oauthService;

  @override
  State<AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends State<AppBootstrap> {
  bool? _onboardingDone;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final done = await isOnboardingComplete();
    if (mounted) setState(() => _onboardingDone = done);
  }

  @override
  Widget build(BuildContext context) {
    if (_onboardingDone == null) {
      return const BrandSplashView(message: '잠시만요');
    }

    if (_onboardingDone == false) {
      return OnboardingScreen(
        apiClient: widget.apiClient,
        onComplete: () => setState(() => _onboardingDone = true),
      );
    }

    return AppShell(
      apiClient: widget.apiClient,
      oauthService: widget.oauthService,
    );
  }
}
