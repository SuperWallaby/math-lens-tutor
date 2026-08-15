import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../layout/tablet_layout.dart';
import '../models/app_models.dart';
import '../services/api_client.dart';
import '../theme/app_design_system.dart';
import '../utils/network_thumbnail_cache.dart';
import 'app_card.dart';
import 'glass.dart';
import 'mixed_math_text.dart';
import 'parent_tab_scaffold.dart';
import 'skeleton_box.dart';

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

const gradeBandKeys = [
  'e12',
  'e34',
  'e56',
  'm1',
  'm2',
  'm3',
  'h1',
  'h2',
  'h3',
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
  if (g.startsWith('대학')) return 8;
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
          color: AppColors.textSub,
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
    this.accent = AppColors.primary,
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
        borderRadius: BorderRadius.circular(AppRadii.lg),
        color: accent.withValues(alpha: 0.12),
        border: Border.all(color: accent.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            greeting,
            style: const TextStyle(color: AppColors.textSub, fontSize: 13),
          ),
          const SizedBox(height: 4),
          Text(
            name,
            style: const TextStyle(
              color: AppColors.text,
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
                  deltaLabel: stats.streakWeeks > 0 ? '연속 유지' : null,
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
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: AppColors.text,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(color: AppColors.textSub, fontSize: 11),
            textAlign: TextAlign.center,
          ),
          if (deltaText != null) ...[
            const SizedBox(height: 4),
            Text(
              deltaText,
              style: const TextStyle(
                color: AppColors.success,
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
          style: TextStyle(color: AppColors.textSub, height: 1.5),
        ),
      );
    }

    return AppCard(
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const Divider(height: 20, color: AppColors.border),
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
    final (icon, color) = switch (item.status) {
      'weak' => (Icons.circle, AppColors.accent),
      'strong' => (Icons.circle, AppColors.success),
      _ => (Icons.circle, AppColors.warning),
    };

    return Row(
      children: [
        Icon(icon, size: 14, color: color),
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
                style: const TextStyle(color: AppColors.textSub, fontSize: 11),
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
      color: AppColors.primary.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(AppRadii.lg),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.lg),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.lg),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.flag_circle_outlined,
                    size: 16,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    '지금 바로 도전',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                mission.title,
                style: const TextStyle(
                  color: AppColors.text,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  height: 1.35,
                ),
              ),
              if (mission.subtitle.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  mission.subtitle,
                  style: const TextStyle(color: AppColors.textSub, fontSize: 13),
                ),
              ],
              const SizedBox(height: 14),
              FilledButton(
                onPressed: onTap,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(44),
                  backgroundColor: AppColors.primary,
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
          style: TextStyle(color: AppColors.textSub),
        ),
      );
    }

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.show_chart_rounded, size: 18, color: AppColors.text),
              const SizedBox(width: 8),
              const Text(
                '정답률 추이',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
              ),
            ],
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
                              color: AppColors.textMuted,
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
                            AppColors.accent,
                            AppColors.success,
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

class GradeBandTabBar extends StatelessWidget {
  const GradeBandTabBar({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: gradeBandLabels.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final selected = selectedIndex == index;
          return Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => onSelected(index),
              borderRadius: BorderRadius.circular(AppRadii.pill),
              child: Ink(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: selected ? AppColors.primary : AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                  border: Border.all(
                    color: selected ? AppColors.primary : AppColors.border,
                  ),
                ),
                child: Center(
                  child: Text(
                    gradeBandLabels[index],
                    style: TextStyle(
                      color: selected ? Colors.white : AppColors.textSub,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class CurriculumProgressList extends StatelessWidget {
  const CurriculumProgressList({
    super.key,
    required this.units,
    this.gradeLabel = '중1',
    this.onUnitTap,
    this.unitActionLabel,
  });

  final List<CurriculumUnitProgress> units;
  final String gradeLabel;
  final void Function(CurriculumUnitProgress unit)? onUnitTap;
  final String? unitActionLabel;

  List<({String section, List<CurriculumUnitProgress> units})> _groupBySection() {
    final groups = <({String section, List<CurriculumUnitProgress> units})>[];
    for (final unit in units) {
      final section = unit.section.trim().isEmpty ? '단원' : unit.section.trim();
      if (groups.isEmpty || groups.last.section != section) {
        groups.add((section: section, units: [unit]));
      } else {
        groups.last.units.add(unit);
      }
    }
    return groups;
  }

  @override
  Widget build(BuildContext context) {
    final sectionGroups = units.isEmpty ? <({String section, List<CurriculumUnitProgress> units})>[] : _groupBySection();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (units.isEmpty)
          AppCard(
            child: Column(
              children: [
                Icon(Icons.menu_book_rounded, size: 36, color: AppColors.primary),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  '$gradeLabel 교육과정',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  '풀이 기록이 쌓이면 단원별 진도가 표시됩니다.',
                  style: TextStyle(color: AppColors.textSub, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          )
        else
          for (var gi = 0; gi < sectionGroups.length; gi++) ...[
            if (gi > 0) const SizedBox(height: AppSpacing.sm),
            _CurriculumSectionGroup(
              section: sectionGroups[gi].section,
              units: sectionGroups[gi].units,
              isFirst: gi == 0,
              onUnitTap: onUnitTap,
              unitActionLabel: unitActionLabel,
            ),
          ],
      ],
    );
  }
}

class _CurriculumSectionGroup extends StatelessWidget {
  const _CurriculumSectionGroup({
    required this.section,
    required this.units,
    required this.isFirst,
    this.onUnitTap,
    this.unitActionLabel,
  });

  final String section;
  final List<CurriculumUnitProgress> units;
  final bool isFirst;
  final void Function(CurriculumUnitProgress unit)? onUnitTap;
  final String? unitActionLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(4, isFirst ? 0 : AppSpacing.xl, 4, AppSpacing.sm),
          child: Text(
            section,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: AppColors.textSub,
              letterSpacing: 0.3,
            ),
          ),
        ),
        for (var i = 0; i < units.length; i++) ...[
          if (i > 0) const SizedBox(height: AppSpacing.sm),
          _UnitCard(
            unit: units[i],
            onTap: onUnitTap,
            actionLabel: unitActionLabel,
          ),
        ],
      ],
    );
  }
}

typedef _UnitStatusStyle = ({IconData icon, Color color, String label});

_UnitStatusStyle _unitStatusStyle(String status) {
  return switch (status) {
    'done' => (
        icon: Icons.check_circle_rounded,
        color: AppColors.success,
        label: '완료',
      ),
    'weak' => (
        icon: Icons.flag_rounded,
        color: AppColors.accent,
        label: '보완 필요',
      ),
    'learning' => (
        icon: Icons.auto_stories_rounded,
        color: AppColors.warning,
        label: '학습 중',
      ),
    _ => (
        icon: Icons.play_arrow_rounded,
        color: AppColors.primary,
        label: '미시작',
      ),
  };
}

class _UnitCard extends StatelessWidget {
  const _UnitCard({
    required this.unit,
    this.onTap,
    this.actionLabel,
  });

  final CurriculumUnitProgress unit;
  final void Function(CurriculumUnitProgress unit)? onTap;
  final String? actionLabel;

  @override
  Widget build(BuildContext context) {
    final style = _unitStatusStyle(unit.status);
    final tappable = onTap != null &&
        (unit.id.isNotEmpty ||
            (actionLabel != null &&
                (unit.percent > 0 || unit.status != 'none')));
    final progressValue = (unit.percent / 100).clamp(0.0, 1.0);

    final content = AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: style.color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(AppRadii.sm),
                ),
                child: Icon(style.icon, color: style.color, size: 24),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            unit.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                              height: 1.35,
                              color: AppColors.text,
                            ),
                          ),
                        ),
                        TagChip(style.label, color: style.color, compact: true),
                      ],
                    ),
                    if (unit.subtitle.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        unit.subtitle,
                        style: const TextStyle(
                          color: AppColors.textSub,
                          fontSize: 12,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                  child: LinearProgressIndicator(
                    value: progressValue > 0 ? progressValue : null,
                    minHeight: 8,
                    backgroundColor: AppColors.surfaceMuted,
                    color: style.color,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                '${unit.percent}%',
                style: TextStyle(
                  color: style.color,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          if (tappable) ...[
            const SizedBox(height: AppSpacing.md),
            Align(
              alignment: Alignment.centerRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    actionLabel ??
                        (unit.status == 'none' ? '단원 학습 시작' : '이어서 학습'),
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(width: 2),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.primary,
                    size: 22,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );

    if (!tappable) return content;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onTap!(unit),
        borderRadius: BorderRadius.circular(AppRadii.md),
        child: content,
      ),
    );
  }
}

Color parentWeeklyStepColor(int step) {
  return switch (step) {
    1 => AppColors.accent,
    2 => AppColors.primary,
    3 => AppColors.success,
    4 => AppColors.warning,
    5 => AppColors.success,
    6 => AppColors.primary,
    7 => AppColors.accent,
    _ => AppColors.warning,
  };
}

class _ParentBodyText extends StatelessWidget {
  const _ParentBodyText(
    this.text, {
    required this.style,
    this.readableSolutionStep = false,
  });

  final String text;
  final TextStyle style;
  final bool readableSolutionStep;

  @override
  Widget build(BuildContext context) {
    if (text.trim().isEmpty) return const SizedBox.shrink();
    return MixedMathText(
      text,
      style: style,
      paragraphSoftBreak: !readableSolutionStep,
      readableSolutionStep: readableSolutionStep,
    );
  }
}

bool parentExplainTitleIsImageFilename(String title) {
  final t = title.trim();
  if (t.isEmpty) return false;
  return RegExp(r'\.(jpe?g|png|webp|heic|gif|jfif)$', caseSensitive: false)
      .hasMatch(t);
}

/// 오답 설명 상세 — 제출 풀이 사진
class ParentSubmissionHeroImage extends StatelessWidget {
  const ParentSubmissionHeroImage({
    super.key,
    required this.imageUrl,
    this.maxHeight = 320,
  });

  final String? imageUrl;
  final double maxHeight;

  @override
  Widget build(BuildContext context) {
    if (imageUrl == null) return const SizedBox.shrink();

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadii.md),
      child: Container(
        width: double.infinity,
        color: AppColors.surfaceMuted,
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Image.network(
          imageUrl!,
          fit: BoxFit.contain,
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return SizedBox(
              height: 180,
              child: Center(
                child: CircularProgressIndicator(
                  value: progress.expectedTotalBytes == null
                      ? null
                      : progress.cumulativeBytesLoaded /
                          progress.expectedTotalBytes!,
                ),
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) => SizedBox(
            height: 120,
            child: Center(
              child: Icon(
                Icons.broken_image_outlined,
                color: AppColors.textMuted.withValues(alpha: 0.7),
                size: 36,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ParentSubmissionThumbnail extends StatelessWidget {
  const _ParentSubmissionThumbnail({required this.imageUrl});

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    const size = 56.0;

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadii.sm),
      child: SizedBox(
        width: size,
        height: size,
        child: imageUrl == null
            ? Container(
                color: AppColors.primary.withValues(alpha: 0.08),
                alignment: Alignment.center,
                child: Icon(
                  Icons.image_outlined,
                  color: AppColors.primary.withValues(alpha: 0.55),
                  size: 24,
                ),
              )
            : Image.network(
                imageUrl!,
                fit: BoxFit.cover,
                cacheWidth: networkImageCacheExtent(size, context),
                cacheHeight: networkImageCacheExtent(size, context),
                errorBuilder: (context, error, stackTrace) => Container(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.broken_image_outlined,
                    color: AppColors.primary.withValues(alpha: 0.55),
                    size: 24,
                  ),
                ),
              ),
      ),
    );
  }
}

class ParentWrongExplainTile extends StatelessWidget {
  const ParentWrongExplainTile({
    super.key,
    required this.item,
    required this.apiBaseUrl,
    this.onTap,
    this.compact = false,
  });

  final ParentWrongExplainItem item;
  final String apiBaseUrl;
  final VoidCallback? onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final imageUrl = ApiClient.resolveListThumbnailUrl(
      apiBaseUrl,
      imageThumbUrl: item.imageThumbUrl,
      imageUrl: item.imageUrl,
    );
    final content = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (item.sourceType == 'submission') ...[
          _ParentSubmissionThumbnail(imageUrl: imageUrl),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TagChip(item.concept, color: AppColors.primary),
              if (item.title.trim().isNotEmpty &&
                  !parentExplainTitleIsImageFilename(item.title)) ...[
                const SizedBox(height: 8),
                _ParentBodyText(
                  item.title,
                  readableSolutionStep: true,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: compact ? 13 : 14,
                    height: 1.4,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              _ParentBodyText(
                item.easyExplain,
                readableSolutionStep: true,
                style: TextStyle(
                  fontSize: compact ? 13 : 14,
                  height: 1.45,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: 8),
              _ParentBodyText(
                item.parentScript,
                readableSolutionStep: true,
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.45,
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );

    if (onTap == null) return content;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: content,
      ),
    );
  }
}

class ParentWeeklyCycleList extends StatelessWidget {
  const ParentWeeklyCycleList({super.key, required this.steps});

  final List<WeeklyReportStep> steps;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < steps.length; i++) ...[
            if (i > 0) const Divider(height: 20, color: AppColors.border),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: parentWeeklyStepColor(steps[i].step),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    '${steps[i].step}',
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
                        steps[i].label,
                        style: TextStyle(
                          color: parentWeeklyStepColor(steps[i].step),
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        steps[i].title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                      _ParentBodyText(
                        steps[i].text,
                        readableSolutionStep: true,
                        style: const TextStyle(
                          color: AppColors.textSub,
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

class ParentActionList extends StatelessWidget {
  const ParentActionList({
    super.key,
    required this.items,
    this.emptyTitle,
    this.emptyBody,
  });

  final List<ParentActionItem> items;
  final String? emptyTitle;
  final String? emptyBody;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      if (emptyTitle == null) return const SizedBox.shrink();
      return ParentEmptyHintCard(
        icon: Icons.check_circle_outline_rounded,
        title: emptyTitle!,
        body: emptyBody ?? '',
        accent: AppColors.success,
      );
    }

    return AppCard(
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const Divider(height: 20, color: AppColors.border),
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
                      _ParentBodyText(
                        items[i].subtitle,
                        style: const TextStyle(
                          color: AppColors.textSub,
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

class ParentCoachingCardWidget extends StatelessWidget {
  const ParentCoachingCardWidget({
    super.key,
    required this.card,
    this.accent = AppColors.success,
  });

  final ParentCoachingCard card;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      tone: GlassTone.blue,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            card.label,
            style: const TextStyle(
              color: AppColors.textSub,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          _ParentBodyText(
            card.question,
            style: const TextStyle(
              color: AppColors.text,
              fontSize: 17,
              fontWeight: FontWeight.w900,
              height: 1.45,
            ),
          ),
          if (card.context.isNotEmpty) ...[
            const SizedBox(height: 10),
            _ParentBodyText(
              card.context,
              style: const TextStyle(
                color: AppColors.textSub,
                fontSize: 13,
                height: 1.45,
              ),
            ),
          ],
          const SizedBox(height: 12),
          GlassPanel(
            tone: GlassTone.sunken,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            borderRadius: BorderRadius.circular(AppRadii.pill),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.flag_outlined,
                  size: 16,
                  color: AppColors.primaryDark,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ParentBodyText(
                    '채점 포인트: ${card.gradingPoint}',
                    readableSolutionStep: true,
                    style: const TextStyle(
                      color: AppColors.text,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ParentWrongExplainPreviewList extends StatelessWidget {
  const ParentWrongExplainPreviewList({
    super.key,
    required this.items,
    required this.apiBaseUrl,
    this.onTapItem,
    this.onSeeAll,
  });

  final List<ParentWrongExplainItem> items;
  final String apiBaseUrl;
  final ValueChanged<ParentWrongExplainItem>? onTapItem;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const AppCard(
        child: Text(
          '아직 틀린 문제 설명이 없어요.\n자녀가 문제를 풀면 이해하기 쉬운 설명이 여기에 쌓입니다.',
          style: TextStyle(color: AppColors.textSub, height: 1.5),
        ),
      );
    }

    final preview = items.take(2).toList();
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < preview.length; i++) ...[
            if (i > 0) const Divider(height: 20, color: AppColors.border),
            ParentWrongExplainTile(
              item: preview[i],
              apiBaseUrl: apiBaseUrl,
              compact: true,
              onTap: onTapItem == null ? null : () => onTapItem!(preview[i]),
            ),
          ],
          if (onSeeAll != null && items.length > 2) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: onSeeAll,
              child: const Text('틀린 문제 설명 더 보기'),
            ),
          ],
        ],
      ),
    );
  }
}

class ParentCompactStats extends StatelessWidget {
  const ParentCompactStats({
    super.key,
    required this.stats,
    required this.studentName,
  });

  final LearningStats stats;
  final String studentName;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          Expanded(
            child: Text(
              '$studentName · 이번 주 ${stats.accuracy}% · ${stats.totalProblems}문제',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSub,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (stats.accuracyDelta != 0)
            TagChip(
              stats.accuracyDelta >= 0
                  ? '+${stats.accuracyDelta}%'
                  : '${stats.accuracyDelta}%',
              color: AppColors.primary,
            ),
        ],
      ),
    );
  }
}

class ProfileLoadingView extends StatelessWidget {
  const ProfileLoadingView({
    super.key,
    this.message = '진도 불러오는 중…',
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: TabletLayout.pagePadding(context),
      children: [
        Text(
          message.replaceAll(RegExp(r'[.…]+$'), ''),
          style: TextStyle(
            fontSize: TabletLayout.titleSection(context),
            fontWeight: FontWeight.w900,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 4),
        const SkeletonBox(width: 180, height: 12, borderRadius: 6),
        const SizedBox(height: 16),
        const SkeletonBox(height: 40, borderRadius: 12),
        const SizedBox(height: 16),
        for (var i = 0; i < 5; i++) ...[
          AppCard(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
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
    final message = switch (error) {
      ApiException(:final message) => message,
      _ => '데이터를 불러오지 못했습니다. 잠시 후 다시 시도해 주세요.',
    };

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSub, height: 1.5),
            ),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onRetry, child: const Text('다시 시도')),
          ],
        ),
      ),
    );
  }
}
