import 'package:flutter/material.dart';

import '../models/app_models.dart';
import '../services/api_client.dart';
import '../widgets/app_card.dart';
import '../widgets/guardian_learning_gate.dart';
import '../widgets/learning_profile_widgets.dart';
import '../widgets/page_stage.dart';
import '../widgets/parent_tab_scaffold.dart';
import '../widgets/skeleton_box.dart';
import '../widgets/student_picker.dart';
import 'open_practice_flow.dart';
import 'practice_screen.dart';
import 'dashboard_screen.dart';
import '../theme/app_icons.dart';

const _studentTitle = '내 진도';
const _guardianTitle = '교육과정 진도';
const _guardianSubtitle = '단원을 눌러 자녀에게 어떻게 도와줄지 확인하세요';
const _notStartedHint = '숙제를 찍으면 그 단원부터 채워져요.';

/// 학년 구간 단원 중 끝낸 단원 수와 전체 단원 수.
/// 끝냄은 단원 목록이 「완료」로 보이는 것과 같은 `status == 'done'`이다.
({int done, int total}) finishedUnits(List<CurriculumUnitProgress> unitsInBand) {
  return (
    done: unitsInBand.where((unit) => unit.status == 'done').length,
    total: unitsInBand.length,
  );
}

/// 구간에 단원이 있는데 하나도 시작하지 않았으면 참.
bool _notStarted(List<CurriculumUnitProgress> units) =>
    units.isNotEmpty && units.every((unit) => unit.percent <= 0);

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
        _profileFuture = Future.value(widget.demoProfile);
      });
      return;
    }
    if (widget.viewAsGuardian &&
        widget.apiClient.authSession.linkedStudents.isEmpty) {
      setState(() {
        _profileFuture = null;
      });
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

  void _onStudentChanged() {
    _gradeTabTouched = false;
    _reload();
  }

  /// 데이터 없이 그릴 수 있는 무대(불러오는 중·오류).
  Widget _emptyStage() {
    return _ProgressStage(
      apiClient: widget.apiClient,
      viewAsGuardian: widget.viewAsGuardian,
      gradeTab: _gradeTab,
      onGradeTabChanged: _onGradeTabChanged,
      onStudentChanged: widget.viewAsGuardian ? _onStudentChanged : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final body = FutureBuilder<LearningProfile>(
      future: _profileFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return StageListView(
            stage: _emptyStage(),
            children: const [_ProgressSkeletonRows()],
          );
        }
        if (snapshot.hasError) {
          return RefreshIndicator(
            onRefresh: () async => _reload(forceRefresh: true),
            child: StageListView(
              stage: _emptyStage(),
              children: [
                ProfileLoadingError(
                  error: snapshot.error,
                  onRetry: () => _reload(forceRefresh: true),
                ),
              ],
            ),
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
          onStudentChanged: widget.viewAsGuardian ? _onStudentChanged : null,
        );
      },
    );

    final framed = StageFrame(child: body);
    if (!widget.viewAsGuardian) return framed;

    return GuardianLearningGate(
      apiClient: widget.apiClient,
      title: _guardianTitle,
      onStudentChanged: _onStudentChanged,
      child: framed,
    );
  }
}

/// 성장 탭 무대: 제목 · 설명 · 학습 통계 원 · (학부모) 자녀 고르기 · 학년 알약 · 숫자 칸.
/// [units]와 [accuracy]가 없으면(불러오는 중·오류) 숫자 칸을 그리지 않는다.
class _ProgressStage extends StatelessWidget {
  const _ProgressStage({
    required this.apiClient,
    required this.viewAsGuardian,
    required this.gradeTab,
    required this.onGradeTabChanged,
    this.onStudentChanged,
    this.units,
    this.accuracy,
  });

  final ApiClient apiClient;
  final bool viewAsGuardian;
  final int gradeTab;
  final ValueChanged<int> onGradeTabChanged;
  final VoidCallback? onStudentChanged;
  final List<CurriculumUnitProgress>? units;
  final int? accuracy;

  @override
  Widget build(BuildContext context) {
    final units = this.units;
    final accuracy = this.accuracy;
    final String subtitle;
    if (viewAsGuardian) {
      subtitle = _guardianSubtitle;
    } else if (units != null && _notStarted(units)) {
      subtitle = _notStartedHint;
    } else {
      subtitle = '2022 개정 교육과정 · ${gradeBandLabels[gradeTab]}';
    }
    final finished = units == null ? null : finishedUnits(units);

    return PageStage.tab(
      title: viewAsGuardian ? _guardianTitle : _studentTitle,
      subtitle: subtitle,
      trailing: StageCircleButton(
        icon: AppIcons.chart,
        tooltip: viewAsGuardian ? '학생 학습 통계' : '학습 통계',
        onPressed: () => DashboardScreen.open(context, apiClient),
      ),
      children: [
        if (viewAsGuardian)
          StudentPicker(
            authSession: apiClient.authSession,
            apiClient: apiClient,
            onChanged: onStudentChanged,
            onStage: true,
          ),
        GradeBandTabBar(
          selectedIndex: gradeTab,
          onSelected: onGradeTabChanged,
          onStage: true,
        ),
        if (finished != null && accuracy != null)
          StageTileRow(
            tiles: [
              StageTile(
                label: '끝낸 단원',
                value: '${finished.done} / ${finished.total}',
              ),
              StageTile(
                label: '정답률',
                value: accuracy > 0 ? '$accuracy%' : '시작 전',
              ),
            ],
          ),
      ],
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

    return RefreshIndicator(
      onRefresh: () async => onReload(forceRefresh: true),
      child: StageListView(
        stage: _ProgressStage(
          apiClient: apiClient,
          viewAsGuardian: viewAsGuardian,
          gradeTab: gradeTab,
          onGradeTabChanged: onGradeTabChanged,
          onStudentChanged: onStudentChanged,
          units: units,
          accuracy: profile.stats.accuracy,
        ),
        children: scrollChildren,
      ),
    );
  }
}

/// 불러오는 중 무대 아래 단원 자리표시.
class _ProgressSkeletonRows extends StatelessWidget {
  const _ProgressSkeletonRows();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < 5; i++) ...[
          const AppCard(
            padding: EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBox(width: 120, height: 14, borderRadius: 6),
                SizedBox(height: 8),
                SkeletonBox(height: 10, borderRadius: 6),
                SizedBox(height: 6),
                SkeletonBox(width: 200, height: 10, borderRadius: 6),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}
