import 'package:flutter/material.dart';

import '../layout/tablet_layout.dart';
import '../models/app_models.dart';
import '../services/api_client.dart';
import '../widgets/app_card.dart';
import '../widgets/mixed_math_text.dart';
import '../widgets/learning_profile_widgets.dart';
import '../widgets/student_picker.dart';
import 'link_student_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    super.key,
    required this.apiClient,
    this.demoInsight,
  });

  final ApiClient apiClient;

  /// 스토어 스크린샷 등 API 없이 고정 데이터를 보여줄 때만 사용합니다.
  final LearningInsight? demoInsight;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Future<LearningProfile>? _profileFuture;
  Future<List<SubmissionSummary>>? _submissionsFuture;
  int _reloadToken = 0;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    if (widget.demoInsight != null) {
      _profileFuture = Future.value(
        LearningProfile(
          grade: '중1',
          insight: widget.demoInsight!,
          stats: LearningStats(
            accuracy: widget.demoInsight!.accuracy,
            accuracyDelta: 0,
            totalProblems: widget.demoInsight!.totalAttempts,
            problemsDelta: 0,
            streakWeeks: 0,
          ),
          conceptStatus: widget.demoInsight!.weakConcepts
              .map(
                (item) => ConceptStatusItem(
                  concept: item.concept,
                  misses: item.misses,
                  status: 'weak',
                  label: '취약',
                ),
              )
              .toList(),
          strongConcepts: const [],
          weeklyTrend: const [],
          curriculumUnits: const [],
          parentActions: const [],
          weeklyReport: const WeeklyReport(
            weekLabel: '데모',
            period: '',
            cycle: [],
            unitMastery: [],
          ),
        ),
      );
      return;
    }

    final token = _reloadToken;
    _profileFuture = widget.apiClient.getLearningProfile();
    if (widget.apiClient.authSession.user?.isGuardian ?? false) {
      _submissionsFuture = widget.apiClient.getSubmissionSummaries();
    } else {
      _submissionsFuture = null;
    }
    setState(() => _reloadToken = token);
  }

  Future<void> _openLinkStudent() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LinkStudentScreen(apiClient: widget.apiClient),
      ),
    );
    if (!mounted) return;
    await widget.apiClient.fetchLinkedStudents();
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    final isGuardian = widget.apiClient.authSession.user?.isGuardian ?? false;

    return Scaffold(
      appBar: AppBar(
        title: Text(isGuardian ? '학생 학습 대시보드' : '학습 대시보드'),
        actions: [
          if (isGuardian)
            IconButton(
              onPressed: _openLinkStudent,
              icon: const Icon(Icons.person_add_alt_1_rounded),
              tooltip: '학생 연결',
            ),
        ],
      ),
      body: SafeArea(
        child: TabletBody(
          child: ListView(
            padding: TabletLayout.pagePadding(context),
            children: [
              if (isGuardian) ...[
                ListenableBuilder(
                  listenable: widget.apiClient.authSession,
                  builder: (context, _) {
                    return StudentPicker(
                      authSession: widget.apiClient.authSession,
                      onChanged: _reload,
                    );
                  },
                ),
                const SizedBox(height: 16),
              ],
              FutureBuilder<LearningProfile>(
                future: _profileFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 48),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  if (snapshot.hasError) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Text(snapshot.error.toString()),
                    );
                  }

                  final profile = snapshot.data!;
                  final insight = profile.insight;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isGuardian ? '선택한 학생 수준 피드백' : '사용자 수준 피드백',
                        style: TextStyle(
                          fontSize: TabletLayout.titleSection(context),
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _MetricCard(
                              title: '현재 수준',
                              value: insight.levelLabel,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _MetricCard(
                              title: '정답률',
                              value: '${insight.accuracy}%',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _MetricCard(
                        title: '숙련도 점수',
                        value: '${insight.masteryScore}',
                        fullWidth: true,
                      ),
                      const SizedBox(height: 16),
                      WeeklyTrendChart(points: profile.weeklyTrend),
                      const SizedBox(height: 16),
                      AppCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('약점 개념', style: _titleStyle),
                            const SizedBox(height: 12),
                            for (final item in insight.weakConcepts)
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(item.concept),
                                trailing: Text('오답 ${item.misses}'),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      AppCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('다음 학습 피드백', style: _titleStyle),
                            const SizedBox(height: 12),
                            for (final feedback in insight.recentFeedback)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      '• ',
                                      style: TextStyle(
                                        color: Color(0xFFCBD5E1),
                                        height: 1.5,
                                      ),
                                    ),
                                    Expanded(
                                      child: MixedMathText(
                                        feedback,
                                        style: const TextStyle(
                                          color: Color(0xFFCBD5E1),
                                          height: 1.5,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
              if (isGuardian && _submissionsFuture != null) ...[
                const SizedBox(height: 24),
                Text(
                  '최근 분석 활동',
                  style: TextStyle(
                    fontSize: TabletLayout.titleSection(context),
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 12),
                FutureBuilder<List<SubmissionSummary>>(
                  future: _submissionsFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Text(snapshot.error.toString());
                    }
                    final items = snapshot.data ?? const [];
                    if (items.isEmpty) {
                      return const Text(
                        '아직 등록된 분석 활동이 없습니다.',
                        style: TextStyle(color: Color(0xFF94A3B8)),
                      );
                    }
                    return Column(
                      children: [
                        for (final item in items)
                          AppCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.imageName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  item.errorSummary,
                                  style: const TextStyle(
                                    color: Color(0xFFCBD5E1),
                                    height: 1.45,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  item.createdAt,
                                  style: const TextStyle(
                                    color: Color(0xFF64748B),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.value,
    this.fullWidth = false,
  });

  final String title;
  final String value;
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Color(0xFF94A3B8))),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: fullWidth ? 30 : 22,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

const _titleStyle = TextStyle(fontSize: 18, fontWeight: FontWeight.w900);
