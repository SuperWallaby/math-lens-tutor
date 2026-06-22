import 'package:flutter/material.dart';

import '../layout/tablet_layout.dart';
import '../models/app_models.dart';
import '../services/api_client.dart';
import '../theme/app_design_system.dart';
import 'student_picker.dart';

/// 학부모 탭 공통 스크롤 — 홈과 동일하게 safe area + StudentPicker 한 번만.
class ParentLinkedScrollView extends StatelessWidget {
  const ParentLinkedScrollView({
    super.key,
    required this.apiClient,
    required this.onStudentChanged,
    required this.children,
    this.onRefresh,
  });

  final ApiClient apiClient;
  final VoidCallback onStudentChanged;
  final List<Widget> children;
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) {
    final body = ListView(
      padding: TabletLayout.pagePadding(context),
      children: [
        StudentPicker(
          authSession: apiClient.authSession,
          apiClient: apiClient,
          onChanged: onStudentChanged,
        ),
        const SizedBox(height: 12),
        ...children,
      ],
    );

    if (onRefresh == null) return body;

    return RefreshIndicator(
      onRefresh: onRefresh!,
      child: body,
    );
  }
}

/// 빈 체크리스트·할 일 등 학부모 탭용 empty 카드
class ParentEmptyHintCard extends StatelessWidget {
  const ParentEmptyHintCard({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    this.accent = AppColors.success,
  });

  final IconData icon;
  final String title;
  final String body;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: accent.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: accent, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  body,
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
    );
  }
}

/// 학부모 진도 탭 — 단원 탭 시 부모 행동 가이드
void showParentUnitGuideSheet(
  BuildContext context, {
  required CurriculumUnitProgress unit,
  required LearningProfile profile,
}) {
  final guidance = switch (unit.status) {
    'weak' =>
      '보완이 필요한 단원이에요. 「설명」 탭에서 틀린 문제를 함께 보고, 홈의 코칭 질문으로 대화를 시작해 보세요.',
    'learning' =>
      '지금 배우는 중이에요. 풀이는 자녀가 앱에서 하고, 학부모님은 격려와 질문으로 도와주세요.',
    'done' =>
      '잘 이해한 단원이에요. 짧게 칭찬해 주시면 다음 학습 동기가 됩니다.',
    _ =>
      '아직 시작 전이에요. 부담 없이 오늘 이 단원부터 시작해 보라고 가볍게 권해 보세요.',
  };

  final statusLabel = switch (unit.status) {
    'done' => '완료',
    'weak' => '보완 필요',
    'learning' => '학습 중',
    _ => '미시작',
  };

  final statusColor = switch (unit.status) {
    'done' => AppColors.success,
    'weak' => AppColors.accent,
    'learning' => AppColors.warning,
    _ => AppColors.primary,
  };

  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) {
      return Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          0,
          24,
          MediaQuery.paddingOf(context).bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              unit.name,
              style: TextStyle(
                fontSize: TabletLayout.titleSection(context) * 0.75,
                fontWeight: FontWeight.w900,
              ),
            ),
            if (unit.subtitle.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                unit.subtitle,
                style: const TextStyle(color: AppColors.textSub, fontSize: 12),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '이해도 ${unit.percent}%',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              '학부모님이 할 수 있는 것',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
            ),
            const SizedBox(height: 8),
            Text(
              guidance,
              style: const TextStyle(
                color: AppColors.textSub,
                height: 1.5,
                fontSize: 14,
              ),
            ),
            if (unit.status == 'weak' &&
                profile.parentWrongExplains.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                '관련: ${profile.parentWrongExplains.first.concept}',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      );
    },
  );
}
