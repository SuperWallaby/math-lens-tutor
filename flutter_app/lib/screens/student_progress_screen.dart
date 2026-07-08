import 'package:flutter/material.dart';

import '../layout/tablet_layout.dart';
import '../models/app_models.dart';
import '../services/api_client.dart';
import '../widgets/guardian_learning_gate.dart';
import '../widgets/learning_profile_widgets.dart';
import '../widgets/parent_tab_scaffold.dart';
import 'open_practice_flow.dart';
import 'practice_screen.dart';
import 'dashboard_screen.dart';
import '../theme/app_design_system.dart';

class StudentProgressScreen extends StatefulWidget {
  const StudentProgressScreen({
    super.key,
    required this.apiClient,
    this.viewAsGuardian = false,
    this.demoProfile,
    this.demoInitialGradeTab,
  });

  final ApiClient apiClient;
  final bool viewAsGuardian;
  final LearningProfile? demoProfile;
  final int? demoInitialGradeTab;

  @override
  State<StudentProgressScreen> createState() => _StudentProgressScreenState();
}

class _StudentProgressScreenState extends State<StudentProgressScreen> {
  Future<LearningProfile>? _profileFuture;
  late int _gradeTab;
  bool _gradeTabTouched = false;

  @override
  void initState() {
    super.initState();
    _gradeTab = widget.demoInitialGradeTab ??
        gradeBandTabIndex(widget.apiClient.authSession.user?.grade);
    _reload();
  }

  void _reload({bool forceRefresh = false}) {
    if (widget.demoProfile != null) {
      setState(() {
        _profileFuture = Future.value(widget.demoProfile);
      });
      return;
    }
    if (widget.viewAsGuardian &&
        widget.apiClient.authSession.linkedStudents.isEmpty) {
      setState(() => _profileFuture = null);
      return;
    }
    setState(() {
      _profileFuture = widget.apiClient.getLearningProfile(
        forceRefresh: forceRefresh,
      );
    });
  }

  void _onGradeTabChanged(int index) {
    setState(() {
      _gradeTab = index;
      _gradeTabTouched = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final body = FutureBuilder<LearningProfile>(
      future: _profileFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const ProfileLoadingView();
        }
        if (snapshot.hasError) {
          return ProfileLoadingError(
            error: snapshot.error,
            onRetry: () => _reload(forceRefresh: true),
          );
        }

        final profile = snapshot.data!;
        final userGradeTab = gradeBandTabIndex(profile.grade);
        if (!_gradeTabTouched && _gradeTab != userGradeTab) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && !_gradeTabTouched) {
              setState(() => _gradeTab = userGradeTab);
            }
          });
        }

        return _ProgressContent(
          apiClient: widget.apiClient,
          viewAsGuardian: widget.viewAsGuardian,
          profile: profile,
          gradeTab: _gradeTab,
          onGradeTabChanged: _onGradeTabChanged,
          onReload: _reload,
          onStudentChanged: widget.viewAsGuardian
              ? () {
                  _gradeTabTouched = false;
                  _reload();
                }
              : null,
        );
      },
    );

    if (!widget.viewAsGuardian) {
      return body;
    }

    return GuardianLearningGate(
      apiClient: widget.apiClient,
      title: '교육과정 진도',
      onStudentChanged: () {
        _gradeTabTouched = false;
        _reload();
      },
      child: body,
    );
  }
}

class _ProgressContent extends StatelessWidget {
  const _ProgressContent({
    required this.apiClient,
    required this.viewAsGuardian,
    required this.profile,
    required this.gradeTab,
    required this.onGradeTabChanged,
    required this.onReload,
    this.onStudentChanged,
  });

  final ApiClient apiClient;
  final bool viewAsGuardian;
  final LearningProfile profile;
  final int gradeTab;
  final ValueChanged<int> onGradeTabChanged;
  final void Function({bool forceRefresh}) onReload;
  final VoidCallback? onStudentChanged;

  @override
  Widget build(BuildContext context) {
    final units = profile.unitsForGradeTab(gradeTab);

    final scrollChildren = [
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  viewAsGuardian ? '교육과정 진도' : '내 진도 현황',
                  style: TextStyle(
                    fontSize: TabletLayout.titleSection(context),
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  viewAsGuardian
                      ? '단원을 눌러 자녀에게 어떻게 도와줄지 확인하세요'
                      : '2022 개정 교육과정 · ${gradeBandLabels[gradeTab]}',
                  style: const TextStyle(color: AppColors.textSub, fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () =>
                DashboardScreen.open(context, apiClient),
            icon: const Icon(Icons.insights_outlined),
            tooltip: viewAsGuardian ? '학생 학습 통계' : '학습 통계',
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
      const SizedBox(height: 12),
      GradeBandTabBar(
        selectedIndex: gradeTab,
        onSelected: onGradeTabChanged,
      ),
      const SizedBox(height: 12),
      CurriculumProgressList(
        units: units,
        gradeLabel: gradeBandLabels[gradeTab],
        unitActionLabel: viewAsGuardian ? '부모 가이드 보기' : null,
        onUnitTap: viewAsGuardian
            ? (unit) {
                showParentUnitGuideSheet(
                  context,
                  unit: unit,
                  profile: profile,
                );
              }
            : (unit) async {
                if (unit.id.isEmpty) return;
                await openPracticeWithSingleRequest(
                  context,
                  apiClient: apiClient,
                  start: () => apiClient.startUnitPractice(unit.id),
                  subtitle: unit.name,
                );
                if (!context.mounted) return;
                onReload(forceRefresh: true);
              },
      ),
      if (!viewAsGuardian && profile.mission?.setId != null) ...[
        SectionLabel('이어서 훈련'),
        OutlinedButton.icon(
          onPressed: () async {
            final setId = profile.mission!.setId!;
            try {
              final set = await apiClient.getProblemSet(setId);
              if (!context.mounted) return;
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => PracticeScreen(
                    apiClient: apiClient,
                    problemSet: set,
                  ),
                ),
              );
              onReload(forceRefresh: true);
            } catch (error) {
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(error.toString())),
              );
            }
          },
          icon: const Icon(Icons.play_arrow_rounded),
          label: const Text('미션 이어하기'),
        ),
      ],
      const SizedBox(height: 24),
    ];

    if (viewAsGuardian && onStudentChanged != null) {
      return ParentLinkedScrollView(
        apiClient: apiClient,
        onStudentChanged: onStudentChanged!,
        onRefresh: () async => onReload(forceRefresh: true),
        children: scrollChildren,
      );
    }

    return RefreshIndicator(
      onRefresh: () async => onReload(forceRefresh: true),
      child: ListView(
        padding: TabletLayout.pagePadding(context),
        children: scrollChildren,
      ),
    );
  }
}
