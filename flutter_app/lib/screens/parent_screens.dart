import 'package:flutter/material.dart';

import '../layout/tablet_layout.dart';
import '../models/app_models.dart';
import '../services/api_client.dart';
import '../widgets/app_card.dart';
import '../widgets/guardian_learning_gate.dart';
import '../widgets/learning_profile_widgets.dart';
import '../widgets/student_picker.dart';
import 'link_student_screen.dart';

class ParentHomeScreen extends StatefulWidget {
  const ParentHomeScreen({super.key, required this.apiClient});

  final ApiClient apiClient;

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

    if (linked.isEmpty) {
      return ListView(
        padding: TabletLayout.pagePadding(context),
        children: [
          StatsHero(
            greeting: '안녕하세요 👋',
            name: user?.displayName ?? '학부모',
            stats: const LearningStats(
              accuracy: 0,
              accuracyDelta: 0,
              totalProblems: 0,
              problemsDelta: 0,
              streakWeeks: 0,
            ),
            accent: const Color(0xFF059669),
          ),
          const SizedBox(height: 20),
          AppCard(
            child: Column(
              children: [
                const Text(
                  '연결된 학생이 없습니다',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                ),
                const SizedBox(height: 8),
                const Text(
                  '학생 고유번호로 연결하면 학습 현황을 확인할 수 있어요.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF94A3B8), height: 1.5),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            LinkStudentScreen(apiClient: widget.apiClient),
                      ),
                    );
                    _reload();
                  },
                  icon: const Icon(Icons.link_rounded),
                  label: const Text('학생 연결하기'),
                ),
              ],
            ),
          ),
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
            return RefreshIndicator(
              onRefresh: () async => _reload(),
              child: ListView(
                padding: TabletLayout.pagePadding(context),
                children: [
                  StudentPicker(
                    authSession: widget.apiClient.authSession,
                    onChanged: _reload,
                  ),
                  const SizedBox(height: 12),
                  StatsHero(
                    greeting: '안녕하세요 👋',
                    name: user?.displayName ?? '학부모',
                    stats: profile.stats,
                    accent: const Color(0xFF059669),
                  ),
                  if (widget.apiClient.authSession.selectedStudent != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      '${widget.apiClient.authSession.selectedStudent!.displayName} 학습 현황',
                      style: const TextStyle(color: Color(0xFF94A3B8)),
                    ),
                  ],
                  SectionLabel('이번 주 요약'),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: LinearGradient(
                        colors: user?.isTeacher == true
                            ? const [Color(0xFF0891B2), Color(0xFF0E7490)]
                            : const [Color(0xFF059669), Color(0xFF047857)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          profile.weeklyReport.weekLabel,
                          style: const TextStyle(
                            color: Color(0xB3FFFFFF),
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          profile.stats.accuracyDelta >= 0
                              ? '전주 대비 ${profile.stats.accuracyDelta}% 향상!'
                              : '이번 주 정답률 ${profile.stats.accuracy}%',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          profile.conceptStatus.isNotEmpty
                              ? '${profile.conceptStatus.first.concept} 집중 공략 중이에요'
                              : '학습 기록이 쌓이고 있어요',
                          style: const TextStyle(
                            color: Color(0xBFFFFFFF),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SectionLabel('약점'),
                  ConceptStatusCard(
                    items: profile.conceptStatus
                        .where((item) => item.status != 'strong')
                        .take(4)
                        .toList(),
                  ),
                  SectionLabel('잘하고 있어요'),
                  if (profile.strongConcepts.isEmpty)
                    const AppCard(
                      child: Text(
                        '아직 강점 개념 데이터가 없습니다.',
                        style: TextStyle(color: Color(0xFF94A3B8)),
                      ),
                    )
                  else
                    AppCard(
                      child: Column(
                        children: [
                          for (var i = 0; i < profile.strongConcepts.length; i++) ...[
                            if (i > 0)
                              const Divider(height: 20, color: Color(0xFF1E293B)),
                            Row(
                              children: [
                                const Text('🟢', style: TextStyle(fontSize: 14)),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    profile.strongConcepts[i].concept,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                                TagChip('${profile.strongConcepts[i].score}%',
                                    color: const Color(0xFF22C55E)),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  SectionLabel('이번 주 부모님이 해주세요'),
                  ParentActionList(items: profile.parentActions),
                  const SizedBox(height: 24),
                ],
              ),
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
      title: '주간 보고서',
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

          final report = snapshot.data!.weeklyReport;
          return ListView(
            padding: TabletLayout.pagePadding(context),
            children: [
              Text(
                '${report.weekLabel} 보고서',
                style: TextStyle(
                  fontSize: TabletLayout.titleSection(context),
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                report.period,
                style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
              ),
              const SizedBox(height: 16),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '📌 이번 주 학습 사이클',
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                    ),
                    const SizedBox(height: 12),
                    for (final step in report.cycle) ...[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: _cycleColor(step.step),
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: Text(
                              '${step.step}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  step.label,
                                  style: TextStyle(
                                    color: _cycleColor(step.step),
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12,
                                  ),
                                ),
                                Text(
                                  step.title,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13,
                                  ),
                                ),
                                Text(
                                  step.text,
                                  style: const TextStyle(
                                    color: Color(0xFF94A3B8),
                                    fontSize: 12,
                                    height: 1.45,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],
                  ],
                ),
              ),
              SectionLabel('단원별 이해도'),
              AppCard(
                child: Column(
                  children: [
                    for (var i = 0; i < report.unitMastery.length; i++) ...[
                      if (i > 0)
                        const Divider(height: 20, color: Color(0xFF1E293B)),
                      _UnitMasteryRow(unit: report.unitMastery[i]),
                    ],
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

  Color _cycleColor(int step) {
    return switch (step) {
      1 => const Color(0xFFEF4444),
      2 => const Color(0xFF2563EB),
      3 => const Color(0xFF22C55E),
      _ => const Color(0xFFF59E0B),
    };
  }
}

class _UnitMasteryRow extends StatelessWidget {
  const _UnitMasteryRow({required this.unit});

  final UnitMastery unit;

  @override
  Widget build(BuildContext context) {
    final color = unit.percent >= 80
        ? const Color(0xFF22C55E)
        : unit.percent >= 60
            ? const Color(0xFFF59E0B)
            : const Color(0xFFEF4444);

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
            backgroundColor: const Color(0xFF1E293B),
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
                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
              ),
              const SizedBox(height: 16),
              WeeklyTrendChart(points: profile.weeklyTrend),
              SectionLabel('주차별 상세'),
              AppCard(
                child: Column(
                  children: [
                    for (var i = 0; i < profile.weeklyTrend.length; i++) ...[
                      if (i > 0)
                        const Divider(height: 20, color: Color(0xFF1E293B)),
                      Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E3A8A),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              profile.weeklyTrend[i].weekLabel,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF93C5FD),
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
                                    color: Color(0xFF94A3B8),
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
                      ? const Color(0xFF22C55E)
                      : const Color(0xFFEF4444),
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
