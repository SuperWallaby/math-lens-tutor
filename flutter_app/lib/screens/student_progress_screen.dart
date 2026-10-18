import 'package:flutter/material.dart';

import '../layout/tablet_layout.dart';
import '../models/app_models.dart';
import '../services/api_client.dart';
import '../widgets/app_card.dart';
import '../widgets/glass.dart';
import '../widgets/guardian_learning_gate.dart';
import '../widgets/learning_profile_widgets.dart';
import '../widgets/parent_tab_scaffold.dart';
import 'open_practice_flow.dart';
import 'practice_screen.dart';
import 'dashboard_screen.dart';
import '../theme/app_design_system.dart';
import '../theme/app_icons.dart';

/// 본문이 이만큼 아래로 스크롤되면 위쪽 흐림(제목)이 나타난다.
const _scrollEdgeThreshold = 30.0;

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
  State<StudentProgressScreen> createState() => StudentProgressScreenState();
}

class StudentProgressScreenState extends State<StudentProgressScreen> {
  Future<LearningProfile>? _profileFuture;
  late int _gradeTab;
  bool _gradeTabTouched = false;
  bool _scrolled = false;

  @override
  void initState() {
    super.initState();
    _gradeTab = widget.demoInitialGradeTab ??
        gradeBandTabIndex(widget.apiClient.authSession.user?.grade);
    // 데모에서 구간을 직접 정했으면 프로필의 학년이 그 구간을 덮어쓰지 않는다.
    _gradeTabTouched = widget.demoInitialGradeTab != null;
    _reload();
  }

  /// 탭 전환 진입 시 호출 — 캐시가 신선하면 재조회를 생략합니다.
  void refreshFromTab({bool forceRefresh = false}) {
    if (widget.demoProfile != null) return;
    if (!forceRefresh &&
        widget.apiClient.isProgressTabDataFresh &&
        _profileFuture != null) {
      return;
    }
    _reload(forceRefresh: forceRefresh);
  }

  void _reload({bool forceRefresh = false}) {
    if (widget.demoProfile != null) {
      setState(() {
        _scrolled = false;
        _profileFuture = Future.value(widget.demoProfile);
      });
      return;
    }
    if (widget.viewAsGuardian &&
        widget.apiClient.authSession.linkedStudents.isEmpty) {
      setState(() {
        _scrolled = false;
        _profileFuture = null;
      });
      return;
    }
    setState(() {
      // 다시 불러오는 동안 스크롤 위치가 사라지므로 흐림도 함께 끈다.
      _scrolled = false;
      _profileFuture = widget.apiClient.getLearningProfile(
        forceRefresh: forceRefresh,
      );
    });
  }

  bool _onScroll(ScrollNotification notification) {
    // 구간 선택처럼 안쪽에서 가로로 스크롤되는 목록은 건너뛴다.
    if (notification.depth != 0 || notification.metrics.axis != Axis.vertical) {
      return false;
    }
    final scrolled = notification.metrics.pixels > _scrollEdgeThreshold;
    if (scrolled != _scrolled && mounted) {
      setState(() => _scrolled = scrolled);
    }
    return false;
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
      return Stack(
        fit: StackFit.expand,
        children: [
          NotificationListener<ScrollNotification>(
            onNotification: _onScroll,
            child: body,
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: GlassScrollEdge(visible: _scrolled, title: '내 진도'),
          ),
        ],
      );
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
                  viewAsGuardian ? '교육과정 진도' : '내 진도',
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
            icon: const Icon(AppIcons.chart),
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
      if (!viewAsGuardian &&
          units.isNotEmpty &&
          units.every((unit) => unit.percent <= 0)) ...[
        _ProgressIntroCard(unitCount: units.length),
        const SizedBox(height: 12),
      ],
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
          icon: const Icon(AppIcons.play),
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

/// 아직 시작한 단원이 하나도 없을 때, 구간 선택 아래에 두는 안내 카드.
class _ProgressIntroCard extends StatelessWidget {
  const _ProgressIntroCard({required this.unitCount});

  final int unitCount;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: SizedBox(
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '0 / $unitCount 단원',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              '숙제를 찍으면 그 단원부터 채워져요.',
              style: TextStyle(
                fontSize: 14,
                height: 1.45,
                color: AppColors.textSub,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
