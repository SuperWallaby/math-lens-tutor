import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../layout/tablet_layout.dart';
import '../models/app_models.dart';
import 'app_card.dart';

const gradeBandLabels = [
  '초1~2',
  '초3~4',
  '초5~6',
  '중1',
  '중2',
  '중3',
  '고1',
  '고2',
  '고3',
];

const gradeBandValues = [
  '초1',
  '초3',
  '초5',
  '중1',
  '중2',
  '중3',
  '고1',
  '고2',
  '고3',
];

int gradeBandTabIndex(String? grade) {
  final g = grade?.trim() ?? '중1';
  if (g.startsWith('초1') || g.startsWith('초2')) return 0;
  if (g.startsWith('초3') || g.startsWith('초4')) return 1;
  if (g.startsWith('초5') || g.startsWith('초6')) return 2;
  if (g.startsWith('중2')) return 4;
  if (g.startsWith('중3')) return 5;
  if (g.startsWith('고1')) return 6;
  if (g.startsWith('고2')) return 7;
  if (g.startsWith('고3')) return 8;
  return 3;
}

String gradeBandPlaceholderTitle(int tabIndex) {
  if (tabIndex < 0 || tabIndex >= gradeBandLabels.length) {
    return '교육과정';
  }
  return '${gradeBandLabels[tabIndex]} 학년';
}

String gradeBandPlaceholderSubtitle(int tabIndex) {
  const subtitles = [
    '9·50까지의 수, 덧셈·뺄셈, 도형, 길이·시간, 규칙 찾기',
    '곱셈·나눗셈, 분수, 도형, 규칙과 대응, 자료 정리',
    '약수·배수, 분수·소수, 비와 비율, 넓이·부피, 가능성',
    '수와 연산·문자와 식·좌표와 그래프·도형·통계 (2022 개정)',
    '유리수·연립방정식·일차함수·도형의 성질·닮음·확률',
    '제곱근·인수분해·이차방정식·이차함수·삼각비·통계',
    '공통수학Ⅰ·Ⅱ — 다항식·방정식·경우의 수·행렬·함수·수열',
    '수학Ⅰ·Ⅱ — 지수·로그·삼각함수·수열·극한·미분·적분',
    '선택과목 — 확률과 통계·미적분·기하',
  ];
  if (tabIndex < 0 || tabIndex >= subtitles.length) {
    return '풀이 기록이 쌓이면 단원별 진도가 표시됩니다.';
  }
  return subtitles[tabIndex];
}

class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 20, 4, 10),
      child: Text(
        text,
        style: TextStyle(
          fontSize: TabletLayout.bodySmall(context),
          fontWeight: FontWeight.w800,
          color: const Color(0xFF94A3B8),
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class StatsHero extends StatelessWidget {
  const StatsHero({
    super.key,
    required this.greeting,
    required this.name,
    required this.stats,
    this.accent = const Color(0xFF2563EB),
  });

  final String greeting;
  final String name;
  final LearningStats stats;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: [accent, Color.lerp(accent, Colors.black, 0.35)!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            greeting,
            style: const TextStyle(color: Color(0xCCFFFFFF), fontSize: 13),
          ),
          const SizedBox(height: 4),
          Text(
            name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _StatBox(
                  value: '${stats.accuracy}%',
                  label: '정답률',
                  delta: stats.accuracyDelta,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatBox(
                  value: '${stats.totalProblems}',
                  label: '푼 문제',
                  delta: stats.problemsDelta,
                  deltaSuffix: '개',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatBox(
                  value: '${stats.streakWeeks}주',
                  label: '연속 학습',
                  delta: stats.streakWeeks > 0 ? 0 : null,
                  deltaLabel: stats.streakWeeks > 0 ? '🔥 유지중' : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  const _StatBox({
    required this.value,
    required this.label,
    this.delta,
    this.deltaSuffix = '%',
    this.deltaLabel,
  });

  final String value;
  final String label;
  final int? delta;
  final String deltaSuffix;
  final String? deltaLabel;

  @override
  Widget build(BuildContext context) {
    final deltaText = deltaLabel ??
        (delta == null
            ? null
            : delta! >= 0
                ? '↑ +$delta$deltaSuffix'
                : '↓ $delta$deltaSuffix');

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
          if (deltaText != null) ...[
            const SizedBox(height: 4),
            Text(
              deltaText,
              style: const TextStyle(
                color: Color(0xFF86EFAC),
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}

class ConceptStatusCard extends StatelessWidget {
  const ConceptStatusCard({super.key, required this.items});

  final List<ConceptStatusItem> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const AppCard(
        child: Text(
          '아직 분석된 약점 개념이 없습니다. 틀린 문제를 업로드해 보세요.',
          style: TextStyle(color: Color(0xFF94A3B8), height: 1.5),
        ),
      );
    }

    return AppCard(
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const Divider(height: 20, color: Color(0xFF1E293B)),
            _ConceptRow(item: items[i]),
          ],
        ],
      ),
    );
  }
}

class _ConceptRow extends StatelessWidget {
  const _ConceptRow({required this.item});

  final ConceptStatusItem item;

  @override
  Widget build(BuildContext context) {
    final (emoji, color) = switch (item.status) {
      'weak' => ('🔴', const Color(0xFFEF4444)),
      'strong' => ('🟢', const Color(0xFF22C55E)),
      _ => ('🟡', const Color(0xFFF59E0B)),
    };

    return Row(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 18)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.concept,
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
              ),
              const SizedBox(height: 2),
              Text(
                item.misses > 0
                    ? '오답 ${item.misses}회 · ${item.label}'
                    : item.label,
                style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
              ),
            ],
          ),
        ),
        TagChip(item.label, color: color),
      ],
    );
  }
}

class MissionCard extends StatelessWidget {
  const MissionCard({
    super.key,
    required this.mission,
    required this.onTap,
  });

  final TodayMission mission;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF1E3A8A),
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '🎯 지금 바로 도전!',
                style: TextStyle(
                  color: Color(0xFF93C5FD),
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                mission.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  height: 1.35,
                ),
              ),
              if (mission.subtitle.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  mission.subtitle,
                  style: const TextStyle(color: Color(0xFFBFDBFE), fontSize: 13),
                ),
              ],
              const SizedBox(height: 14),
              FilledButton(
                onPressed: onTap,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(44),
                  backgroundColor: const Color(0xFF2563EB),
                ),
                child: Text(
                  mission.remainingCount > 0
                      ? '지금 풀기 (${mission.remainingCount}개 남음) →'
                      : '지금 풀기 →',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class WeeklyTrendChart extends StatelessWidget {
  const WeeklyTrendChart({super.key, required this.points});

  final List<WeeklyTrendPoint> points;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return const AppCard(
        child: Text(
          '아직 주간 추이 데이터가 없습니다.',
          style: TextStyle(color: Color(0xFF94A3B8)),
        ),
      );
    }

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '📈 정답률 추이',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 180,
            child: BarChart(
              BarChartData(
                borderData: FlBorderData(show: false),
                gridData: const FlGridData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(),
                  rightTitles: const AxisTitles(),
                  leftTitles: const AxisTitles(),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index < 0 || index >= points.length) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            points[index].weekLabel,
                            style: const TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 11,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                barGroups: [
                  for (var i = 0; i < points.length; i++)
                    BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: points[i].accuracy.toDouble(),
                          color: Color.lerp(
                            const Color(0xFFEF4444),
                            const Color(0xFF22C55E),
                            points[i].accuracy / 100,
                          )!,
                          width: 22,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class CurriculumProgressList extends StatelessWidget {
  const CurriculumProgressList({
    super.key,
    required this.units,
    this.chainWarning,
    this.gradeLabel = '중1',
  });

  final List<CurriculumUnitProgress> units;
  final String? chainWarning;
  final String gradeLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (chainWarning != null && chainWarning!.isNotEmpty) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF7F1D1D).withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.3)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('⚠️', style: TextStyle(fontSize: 20)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '개념 연결고리 주의!',
                        style: TextStyle(
                          color: Color(0xFFFCA5A5),
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        chainWarning!,
                        style: const TextStyle(
                          color: Color(0xFFCBD5E1),
                          fontSize: 12,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (units.isEmpty)
          AppCard(
            child: Column(
              children: [
                const Text('📖', style: TextStyle(fontSize: 32)),
                const SizedBox(height: 8),
                Text(
                  '$gradeLabel 교육과정',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  '풀이 기록이 쌓이면 단원별 진도가 표시됩니다.',
                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          )
        else
          AppCard(
            child: Column(
              children: [
                for (var i = 0; i < units.length; i++) ...[
                  if (i > 0) const Divider(height: 20, color: Color(0xFF1E293B)),
                  _UnitRow(unit: units[i]),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _UnitRow extends StatelessWidget {
  const _UnitRow({required this.unit});

  final CurriculumUnitProgress unit;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (unit.status) {
      'done' => ('✅', const Color(0xFF22C55E)),
      'weak' => ('🔴', const Color(0xFFEF4444)),
      'learning' => ('🔄', const Color(0xFFF59E0B)),
      _ => ('⬜', const Color(0xFF64748B)),
    };

    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(icon),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                unit.name,
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
              ),
              if (unit.subtitle.isNotEmpty)
                Text(
                  unit.subtitle,
                  style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                ),
              if (unit.percent > 0) ...[
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
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          unit.percent > 0 ? '${unit.percent}%' : '-',
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w800,
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}

class ParentActionList extends StatelessWidget {
  const ParentActionList({super.key, required this.items});

  final List<ParentActionItem> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    return AppCard(
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const Divider(height: 20, color: Color(0xFF1E293B)),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(items[i].icon, style: const TextStyle(fontSize: 22)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        items[i].title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        items[i].subtitle,
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
          ],
        ],
      ),
    );
  }
}

class ProfileLoadingError extends StatelessWidget {
  const ProfileLoadingError({
    super.key,
    required this.error,
    required this.onRetry,
  });

  final Object? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(error.toString(), textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onRetry, child: const Text('다시 시도')),
          ],
        ),
      ),
    );
  }
}
