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
  static const _studentTrainingTabIndex = 2;
  static const _studentProgressTabIndex = 3;

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
        if (user.role == AppUserRole.student) {
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

        final tabs = _tabsFor(user.role);
        final safeIndex = _index.clamp(0, tabs.length - 1);
        if (safeIndex != _index) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _index = safeIndex);
          });
        }

        return Scaffold(
          backgroundColor: Colors.transparent,
          body: GlassAtmosphere(
            child: IndexedStack(
              index: safeIndex,
              children: tabs.map((tab) => tab.screen).toList(),
            ),
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: safeIndex,
            onDestinationSelected: (value) {
              setState(() => _index = value);
              if (user.role == AppUserRole.student) {
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
            destinations: [
              for (var i = 0; i < tabs.length; i++)
                NavigationDestination(
                  icon: _showTrainingBadge(user.role, i)
                      ? Badge.count(
                          count: _trainingBadgeCount,
                          child: Icon(tabs[i].icon),
                        )
                      : Icon(tabs[i].icon),
                  selectedIcon: Icon(tabs[i].selectedIcon),
                  label: tabs[i].label,
                ),
            ],
          ),
        );
      },
    );
  }

  bool _showTrainingBadge(AppUserRole? role, int tabIndex) {
    return role == AppUserRole.student &&
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
            icon: Icons.home_outlined,
            selectedIcon: Icons.home_rounded,
            screen: ParentHomeScreen(apiClient: widget.apiClient),
          ),
          _ShellTab(
            label: '설명',
            icon: Icons.menu_book_outlined,
            selectedIcon: Icons.menu_book_rounded,
            screen: ParentExplainScreen(apiClient: widget.apiClient),
          ),
          _ShellTab(
            label: '이번 주',
            icon: Icons.task_alt_outlined,
            selectedIcon: Icons.task_alt_rounded,
            screen: ParentReportScreen(apiClient: widget.apiClient),
          ),
          _ShellTab(
            label: '진도',
            icon: Icons.route_outlined,
            selectedIcon: Icons.route_rounded,
            screen: StudentProgressScreen(
              apiClient: widget.apiClient,
              viewAsGuardian: true,
            ),
          ),
          _ShellTab(
            label: '설정',
            icon: Icons.settings_outlined,
            selectedIcon: Icons.settings_rounded,
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
            icon: Icons.home_outlined,
            selectedIcon: Icons.home_rounded,
            screen: TeacherHomeScreen(apiClient: widget.apiClient),
          ),
          _ShellTab(
            label: '학생',
            icon: Icons.person_outline_rounded,
            selectedIcon: Icons.person_rounded,
            screen: TeacherStudentDetailScreen(apiClient: widget.apiClient),
          ),
          _ShellTab(
            label: '반진도',
            icon: Icons.groups_outlined,
            selectedIcon: Icons.groups_rounded,
            screen: TeacherClassProgressScreen(apiClient: widget.apiClient),
          ),
          _ShellTab(
            label: '설정',
            icon: Icons.settings_outlined,
            selectedIcon: Icons.settings_rounded,
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
            icon: Icons.home_outlined,
            selectedIcon: Icons.home_rounded,
            screen: StudentHubScreen(
              key: _studentHubKey,
              apiClient: widget.apiClient,
              oauthService: widget.oauthService,
            ),
          ),
          _ShellTab(
            label: '업로드',
            icon: Icons.camera_alt_outlined,
            selectedIcon: Icons.camera_alt_rounded,
            screen: UploadScreen(
              apiClient: widget.apiClient,
              embeddedInShell: true,
            ),
          ),
          _ShellTab(
            label: '맞춤훈련',
            icon: Icons.edit_note_outlined,
            selectedIcon: Icons.edit_note_rounded,
            screen: StudentTrainingScreen(
              key: _studentTrainingKey,
              apiClient: widget.apiClient,
            ),
          ),
          _ShellTab(
            label: '진도',
            icon: Icons.menu_book_outlined,
            selectedIcon: Icons.menu_book_rounded,
            screen: StudentProgressScreen(
              key: _studentProgressKey,
              apiClient: widget.apiClient,
            ),
          ),
          _ShellTab(
            label: '설정',
            icon: Icons.settings_outlined,
            selectedIcon: Icons.settings_rounded,
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
