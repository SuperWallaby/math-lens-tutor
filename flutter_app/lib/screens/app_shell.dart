import 'package:flutter/material.dart';

import '../models/app_models.dart';
import '../services/api_client.dart';
import 'onboarding_screen.dart';
import 'parent_screens.dart';
import 'settings_screen.dart';
import 'student_hub_screen.dart';
import 'student_progress_screen.dart';
import 'student_training_screen.dart';
import 'teacher_screens.dart';
import 'upload_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.apiClient});

  final ApiClient apiClient;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

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
          body: IndexedStack(
            index: safeIndex,
            children: tabs.map((tab) => tab.screen).toList(),
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: safeIndex,
            onDestinationSelected: (value) => setState(() => _index = value),
            destinations: [
              for (final tab in tabs)
                NavigationDestination(
                  icon: Icon(tab.icon),
                  selectedIcon: Icon(tab.selectedIcon),
                  label: tab.label,
                ),
            ],
          ),
        );
      },
    );
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
            label: '보고서',
            icon: Icons.description_outlined,
            selectedIcon: Icons.description_rounded,
            screen: ParentReportScreen(apiClient: widget.apiClient),
          ),
          _ShellTab(
            label: '진도',
            icon: Icons.menu_book_outlined,
            selectedIcon: Icons.menu_book_rounded,
            screen: StudentProgressScreen(
              apiClient: widget.apiClient,
              viewAsGuardian: true,
            ),
          ),
          _ShellTab(
            label: '성장',
            icon: Icons.show_chart_outlined,
            selectedIcon: Icons.show_chart_rounded,
            screen: ParentGrowthScreen(apiClient: widget.apiClient),
          ),
          _ShellTab(
            label: '설정',
            icon: Icons.settings_outlined,
            selectedIcon: Icons.settings_rounded,
            screen: SettingsScreen(apiClient: widget.apiClient),
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
            screen: SettingsScreen(apiClient: widget.apiClient),
          ),
        ];
      case AppUserRole.student:
      default:
        return [
          _ShellTab(
            label: '홈',
            icon: Icons.home_outlined,
            selectedIcon: Icons.home_rounded,
            screen: StudentHubScreen(apiClient: widget.apiClient),
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
            label: '훈련',
            icon: Icons.edit_note_outlined,
            selectedIcon: Icons.edit_note_rounded,
            screen: StudentTrainingScreen(apiClient: widget.apiClient),
          ),
          _ShellTab(
            label: '진도',
            icon: Icons.menu_book_outlined,
            selectedIcon: Icons.menu_book_rounded,
            screen: StudentProgressScreen(apiClient: widget.apiClient),
          ),
          _ShellTab(
            label: '설정',
            icon: Icons.settings_outlined,
            selectedIcon: Icons.settings_rounded,
            screen: SettingsScreen(apiClient: widget.apiClient),
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
  const AppBootstrap({super.key, required this.apiClient});

  final ApiClient apiClient;

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
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_onboardingDone == false) {
      return OnboardingScreen(
        onComplete: () => setState(() => _onboardingDone = true),
      );
    }

    return AppShell(apiClient: widget.apiClient);
  }
}
