import 'package:flutter/material.dart';

import 'parent_explain_screen.dart';
import '../layout/tablet_layout.dart';
import '../models/app_models.dart';
import '../services/api_client.dart';
import '../widgets/app_card.dart';
import '../widgets/guardian_learning_gate.dart';
import '../widgets/learning_profile_widgets.dart';
import '../widgets/hero_icon_3d.dart';
import '../widgets/linked_children_panel.dart';
import '../widgets/student_link_guide.dart';
import '../widgets/parent_tab_scaffold.dart';
import '../theme/app_design_system.dart';

class ParentHomeScreen extends StatefulWidget {
  const ParentHomeScreen({
    super.key,
    required this.apiClient,
    this.demoProfile,
  });

  final ApiClient apiClient;
  final LearningProfile? demoProfile;

  @override
  State<ParentHomeScreen> createState() => _ParentHomeScreenState();
}

class _ParentHomeScreenState extends State<ParentHomeScreen> {
  Future<LearningProfile>? _profileFuture;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    if (widget.demoProfile != null) {
      _profileFuture = Future.value(widget.demoProfile);
      setState(() {});
      return;
    }
    if (widget.apiClient.authSession.linkedStudents.isEmpty) {
      _profileFuture = null;
      setState(() {});
      return;
    }
    setState(() {
      _profileFuture = widget.apiClient.getLearningProfile();
    });
  }

  @override
  Widget build(BuildContext context) {
    final linked = widget.apiClient.authSession.linkedStudents;
    final user = widget.apiClient.authSession.user;

    if (widget.demoProfile == null && linked.isEmpty) {
      final isParent = user?.role == AppUserRole.parent;
      return ListView(
        padding: TabletLayout.pagePadding(context),
        children: [
          const SizedBox(height: 24),
          Center(
            child: HeroIcon3d(
              asset: 'assets/icons/3d/link_empty.png',
              tint: isParent ? AppColors.success : AppColors.teacher,
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
          Text(
            isParent ? '자녀를 연결해 주세요' : '학생을 연결해 주세요',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: TabletLayout.titleSection(context),
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          const Text(
            '고유번호 6자리를 모두 입력하면 자동으로 연결됩니다.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSub, height: 1.55),
          ),
          const SizedBox(height: AppSpacing.section),
          ListenableBuilder(
            listenable: widget.apiClient.authSession,
            builder: (context, _) {
              return LinkedChildrenPanel(
                apiClient: widget.apiClient,
                linkedStudents: widget.apiClient.authSession.linkedStudents,
                compact: true,
                onChanged: _reload,
                onAutoLinked: _reload,
              );
            },
          ),
          const SizedBox(height: AppSpacing.sm),
          StudentLinkGuide(role: user?.role),
          SizedBox(height: MediaQuery.paddingOf(context).bottom + AppSpacing.lg),
        ],
      );
    }

    return ListenableBuilder(
      listenable: widget.apiClient.authSession,
      builder: (context, _) {
        return FutureBuilder<LearningProfile>(
          future: _profileFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return ProfileLoadingError(error: snapshot.error, onRetry: _reload);
            }

            final profile = snapshot.data!;
            final studentName =
                widget.apiClient.authSession.selectedStudent?.labelForGuardian ??
                    '자녀';

            Future<void> openExplainDetail(ParentWrongExplainItem item) async {
              await Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (context) => ParentExplainDetailScreen(
                    apiClient: widget.apiClient,
                    item: item,
                  ),
                ),
              );
            }

            return ParentLinkedScrollView(
              apiClient: widget.apiClient,
              onStudentChanged: _reload,
              onRefresh: () async => _reload(),
              showStudentPicker: widget.demoProfile == null,
              children: [
                Text(
                  '안녕하세요, ${user?.displayName ?? '학부모'}님',
                    style: TextStyle(
                      fontSize: TabletLayout.titleSection(context),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '오늘은 이렇게 도와주시면 좋아요',
                    style: const TextStyle(color: AppColors.textSub),
                  ),
                  const SizedBox(height: 16),
                  if (profile.parentCoachingCard != null)
                    ParentCoachingCardWidget(
                      card: profile.parentCoachingCard!,
                      accent: AppColors.success,
                    )
                  else
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '오늘의 부모 코칭',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: AppColors.textSub,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '$studentName가 문제를 풀면, 대화용 코칭 질문이 여기에 표시됩니다.',
                            style: const TextStyle(height: 1.5),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 12),
                  ParentCompactStats(
                    stats: profile.stats,
                    studentName: studentName,
                  ),
                  const SectionLabel('틀린 문제, 이렇게 도와주세요'),
                  ParentWrongExplainPreviewList(
                    items: profile.parentWrongExplains,
                    apiBaseUrl: widget.apiClient.baseUrl,
                    onTapItem: openExplainDetail,
                  ),
                  const SectionLabel('오늘 할 일'),
                  ParentActionList(
                    items: profile.parentActions,
                    emptyTitle: '오늘 할 일이 비어 있어요',
                    emptyBody:
                        '자녀가 문제를 풀거나 틀리면, 확인·대화·칭찬할 항목이 여기에 쌓입니다.',
                  ),
                  const SizedBox(height: 24),
                ],
              );
          },
        );
      },
    );
  }
}

class ParentReportScreen extends StatefulWidget {
  const ParentReportScreen({super.key, required this.apiClient});

  final ApiClient apiClient;

  @override
  State<ParentReportScreen> createState() => _ParentReportScreenState();
}

class _ParentReportScreenState extends State<ParentReportScreen> {
  Future<LearningProfile>? _profileFuture;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    setState(() {
      _profileFuture = widget.apiClient.getLearningProfile();
    });
  }

  @override
  Widget build(BuildContext context) {
    return GuardianLearningGate(
      apiClient: widget.apiClient,
      title: '이번 주 할 일',
      onStudentChanged: _reload,
      child: FutureBuilder<LearningProfile>(
        future: _profileFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return ProfileLoadingError(error: snapshot.error, onRetry: _reload);
          }

          final profile = snapshot.data!;
          final report = profile.weeklyReport;
          final parentSteps =
              report.cycle.where((step) => step.step >= 5).toList();

          return ParentLinkedScrollView(
            apiClient: widget.apiClient,
            onStudentChanged: _reload,
            children: [
              Text(
                '${report.weekLabel} · 부모 가이드',
                style: TextStyle(
                  fontSize: TabletLayout.titleSection(context),
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                report.period,
                style: const TextStyle(color: AppColors.textSub, fontSize: 12),
              ),
              const SizedBox(height: 16),
              if (profile.parentCoachingCard != null)
                ParentCoachingCardWidget(
                  card: profile.parentCoachingCard!,
                  accent: AppColors.success,
                ),
              const SectionLabel('이번 주 체크리스트'),
              ParentActionList(
                items: profile.parentActions,
                emptyTitle: '이번 주 체크리스트가 비어 있어요',
                emptyBody:
                    '학습 기록이 쌓이면 확인·대화·칭찬할 항목이 자동으로 채워집니다. 홈의 코칭 카드도 함께 확인해 보세요.',
              ),
              const SectionLabel('학습 루프 · 부모 역할'),
              ParentWeeklyCycleList(
                steps: parentSteps.isNotEmpty ? parentSteps : report.cycle,
              ),
              SectionLabel('참고 · 단원 이해도'),
              AppCard(
                child: Column(
                  children: [
                    for (var i = 0; i < report.unitMastery.length; i++) ...[
                      if (i > 0)
                        const Divider(height: 20, color: AppColors.border),
                      _UnitMasteryRow(unit: report.unitMastery[i]),
                    ],
                    if (report.unitMastery.isEmpty)
                      const Text(
                        '진도 데이터가 쌓이면 참고용으로 표시됩니다.',
                        style: TextStyle(color: AppColors.textSub, fontSize: 12),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
  }
}

class _UnitMasteryRow extends StatelessWidget {
  const _UnitMasteryRow({required this.unit});

  final UnitMastery unit;

  @override
  Widget build(BuildContext context) {
    final color = unit.percent >= 80
        ? AppColors.success
        : unit.percent >= 60
            ? AppColors.warning
            : AppColors.accent;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              unit.name,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
            ),
            Text(
              '${unit.percent}%',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            value: unit.percent / 100,
            minHeight: 6,
            backgroundColor: AppColors.surfaceMuted,
            color: color,
          ),
        ),
      ],
    );
  }
}

class ParentGrowthScreen extends StatefulWidget {
  const ParentGrowthScreen({super.key, required this.apiClient});

  final ApiClient apiClient;

  @override
  State<ParentGrowthScreen> createState() => _ParentGrowthScreenState();
}

class _ParentGrowthScreenState extends State<ParentGrowthScreen> {
  Future<LearningProfile>? _profileFuture;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    setState(() {
      _profileFuture = widget.apiClient.getLearningProfile();
    });
  }

  @override
  Widget build(BuildContext context) {
    return GuardianLearningGate(
      apiClient: widget.apiClient,
      title: '성장 그래프',
      onStudentChanged: _reload,
      child: FutureBuilder<LearningProfile>(
        future: _profileFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return ProfileLoadingError(error: snapshot.error, onRetry: _reload);
          }

          final profile = snapshot.data!;
          final delta = profile.stats.accuracyDelta;

          return ListView(
            padding: TabletLayout.pagePadding(context),
            children: [
              Text(
                '성장 그래프',
                style: TextStyle(
                  fontSize: TabletLayout.titleSection(context),
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                '4주간 정답률 변화',
                style: TextStyle(color: AppColors.textSub, fontSize: 12),
              ),
              const SizedBox(height: 16),
              WeeklyTrendChart(points: profile.weeklyTrend),
              SectionLabel('주차별 상세'),
              AppCard(
                child: Column(
                  children: [
                    for (var i = 0; i < profile.weeklyTrend.length; i++) ...[
                      if (i > 0)
                        const Divider(height: 20, color: AppColors.border),
                      Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              profile.weeklyTrend[i].weekLabel,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '정답률 ${profile.weeklyTrend[i].accuracy}%',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13,
                                  ),
                                ),
                                Text(
                                  profile.weeklyTrend[i].summary,
                                  style: const TextStyle(
                                    color: AppColors.textSub,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              if (delta != 0) ...[
                const SizedBox(height: 12),
                TagChip(
                  delta >= 0 ? '+$delta% 향상' : '$delta% 변화',
                  color: delta >= 0
                      ? AppColors.success
                      : AppColors.accent,
                ),
              ],
              const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
  }
}
