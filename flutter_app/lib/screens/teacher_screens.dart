import 'package:flutter/material.dart';

import '../layout/tablet_layout.dart';
import '../models/app_models.dart';
import '../services/api_client.dart';
import '../widgets/app_card.dart';
import '../widgets/learning_profile_widgets.dart';
import 'link_student_screen.dart';
import 'student_progress_screen.dart';

class TeacherHomeScreen extends StatefulWidget {
  const TeacherHomeScreen({super.key, required this.apiClient});

  final ApiClient apiClient;

  @override
  State<TeacherHomeScreen> createState() => _TeacherHomeScreenState();
}

class _TeacherHomeScreenState extends State<TeacherHomeScreen> {
  Future<TeacherClassOverview>? _overviewFuture;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    setState(() {
      _overviewFuture = widget.apiClient.getTeacherOverview();
    });
  }

  Future<void> _openLinkStudent() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LinkStudentScreen(apiClient: widget.apiClient),
      ),
    );
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.apiClient.authSession.user;

    return FutureBuilder<TeacherClassOverview>(
      future: _overviewFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return ProfileLoadingError(error: snapshot.error, onRetry: _reload);
        }

        final overview = snapshot.data!;
        return RefreshIndicator(
          onRefresh: () async => _reload(),
          child: ListView(
            padding: TabletLayout.pagePadding(context),
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0891B2), Color(0xFF0E7490)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '안녕하세요 👩‍🏫',
                      style: TextStyle(color: Color(0xCCFFFFFF), fontSize: 13),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user?.displayName ?? '선생님',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (overview.organizationName != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        overview.organizationName!,
                        style: const TextStyle(
                          color: Color(0xB3FFFFFF),
                          fontSize: 13,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _TeacherStatBox(
                            value: '${overview.totalStudents}',
                            label: '담당 학생',
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _TeacherStatBox(
                            value: '${overview.atRiskCount}명',
                            label: '즉시 관리',
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _TeacherStatBox(
                            value: '${overview.classAverageAccuracy}%',
                            label: '반 평균',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Material(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(18),
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: _openLinkStudent,
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: const Color(0xFF0891B2).withValues(alpha: 0.3),
                        width: 1.5,
                      ),
                    ),
                    child: const Row(
                      children: [
                        Text('+', style: TextStyle(fontSize: 24, color: Color(0xFF0891B2))),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '학생 추가',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                '학생 코드를 입력하세요',
                                style: TextStyle(
                                  color: Color(0xFF94A3B8),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (overview.dangerStudents.isNotEmpty) ...[
                SectionLabel('즉시 관리 필요'),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF7F1D1D).withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('🚨', style: TextStyle(fontSize: 22)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${overview.atRiskCount}명이 정답률 40% 미만이에요!',
                              style: const TextStyle(
                                color: Color(0xFFFCA5A5),
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              overview.dangerStudents
                                  .map((s) => s.displayName)
                                  .join(' · '),
                              style: const TextStyle(
                                color: Color(0xFFCBD5E1),
                                fontSize: 12,
                                height: 1.45,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              SectionLabel('전체 학생 현황'),
              if (overview.students.isEmpty)
                const AppCard(
                  child: Text(
                    '연결된 학생이 없습니다. 학생 코드로 추가해 주세요.',
                    style: TextStyle(color: Color(0xFF94A3B8), height: 1.5),
                  ),
                )
              else
                AppCard(
                  child: Column(
                    children: [
                      for (var i = 0; i < overview.students.length; i++) ...[
                        if (i > 0)
                          const Divider(height: 20, color: Color(0xFF1E293B)),
                        _TeacherStudentRow(
                          student: overview.students[i],
                          onTap: () async {
                            await widget.apiClient.authSession
                                .setViewAsStudentId(overview.students[i].id);
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  '${overview.students[i].displayName} 학생을 선택했습니다.',
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }
}

class _TeacherStudentRow extends StatelessWidget {
  const _TeacherStudentRow({required this.student, required this.onTap});

  final TeacherStudentRow student;
  final VoidCallback onTap;

  Color get _color {
    return switch (student.status) {
      'danger' => const Color(0xFFEF4444),
      'warning' => const Color(0xFFF59E0B),
      'good' => const Color(0xFF22C55E),
      _ => const Color(0xFF2563EB),
    };
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: _color.withValues(alpha: 0.15),
            foregroundColor: _color,
            child: Text(
              student.displayName.isNotEmpty ? student.displayName[0] : '?',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  student.displayName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
                Text(
                  student.weakConcept.isNotEmpty
                      ? '${student.weakConcept} · ${student.statusLabel}'
                      : student.statusLabel,
                  style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: student.accuracy / 100,
                    minHeight: 5,
                    backgroundColor: const Color(0xFF1E293B),
                    color: _color,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${student.accuracy}%',
                style: TextStyle(
                  color: _color,
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              TagChip(student.statusLabel, color: _color),
            ],
          ),
        ],
      ),
    );
  }
}

class TeacherStudentDetailScreen extends StatefulWidget {
  const TeacherStudentDetailScreen({super.key, required this.apiClient});

  final ApiClient apiClient;

  @override
  State<TeacherStudentDetailScreen> createState() =>
      _TeacherStudentDetailScreenState();
}

class _TeacherStudentDetailScreenState extends State<TeacherStudentDetailScreen> {
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
    final selected = widget.apiClient.authSession.selectedStudent;

    if (selected == null) {
      return ListView(
        padding: TabletLayout.pagePadding(context),
        children: [
          const AppCard(
            child: Text(
              '홈 탭에서 학생을 선택하면 상세 현황을 볼 수 있습니다.',
              style: TextStyle(color: Color(0xFF94A3B8), height: 1.5),
            ),
          ),
        ],
      );
    }

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
        return ListView(
          padding: TabletLayout.pagePadding(context),
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: const Color(0xFFEF4444).withValues(alpha: 0.15),
                  foregroundColor: const Color(0xFFEF4444),
                  child: Text(
                    selected.displayName.isNotEmpty
                        ? selected.displayName[0]
                        : '?',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        selected.displayName,
                        style: TextStyle(
                          fontSize: TabletLayout.titleSection(context),
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        selected.studentCode,
                        style: const TextStyle(color: Color(0xFF94A3B8)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: AppCard(
                    child: Column(
                      children: [
                        Text(
                          '${profile.stats.accuracy}%',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFFEF4444),
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          '이번 주 정답률',
                          style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: AppCard(
                    child: Column(
                      children: [
                        Text(
                          '${profile.stats.totalProblems}',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFFF97316),
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          '푼 문제',
                          style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            SectionLabel('약점 개념'),
            ConceptStatusCard(items: profile.conceptStatus),
            SectionLabel('최근 피드백'),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final feedback in profile.insight.recentFeedback)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        '• $feedback',
                        style: const TextStyle(
                          color: Color(0xFFCBD5E1),
                          height: 1.45,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        );
      },
    );
  }
}

class TeacherClassProgressScreen extends StatefulWidget {
  const TeacherClassProgressScreen({super.key, required this.apiClient});

  final ApiClient apiClient;

  @override
  State<TeacherClassProgressScreen> createState() =>
      _TeacherClassProgressScreenState();
}

class _TeacherClassProgressScreenState extends State<TeacherClassProgressScreen> {
  Future<TeacherClassOverview>? _overviewFuture;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    setState(() {
      _overviewFuture = widget.apiClient.getTeacherOverview();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<TeacherClassOverview>(
      future: _overviewFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return ProfileLoadingError(error: snapshot.error, onRetry: _reload);
        }

        final overview = snapshot.data!;
        return ListView(
          padding: TabletLayout.pagePadding(context),
          children: [
            Text(
              '반 진도 현황',
              style: TextStyle(
                fontSize: TabletLayout.titleSection(context),
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 16),
            AppCard(
              child: Column(
                children: [
                  for (var i = 0; i < overview.classUnitAverages.length; i++) ...[
                    if (i > 0) const Divider(height: 20, color: Color(0xFF1E293B)),
                    _UnitMasteryRow(unit: overview.classUnitAverages[i]),
                  ],
                ],
              ),
            ),
            SectionLabel('지도 추천'),
            ParentActionList(items: overview.recommendations),
            if (widget.apiClient.authSession.selectedStudent != null) ...[
              SectionLabel('선택 학생'),
              AppCard(
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.apiClient.authSession.selectedStudent!.displayName,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    OutlinedButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => StudentProgressScreen(
                              apiClient: widget.apiClient,
                              viewAsGuardian: true,
                            ),
                          ),
                        );
                      },
                      child: const Text('진도 보기'),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
          ],
        );
      },
    );
  }
}

class _TeacherStatBox extends StatelessWidget {
  const _TeacherStatBox({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(color: Color(0xCCFFFFFF), fontSize: 11),
            textAlign: TextAlign.center,
          ),
        ],
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
