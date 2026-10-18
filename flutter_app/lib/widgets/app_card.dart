import 'package:flutter/material.dart';

import '../theme/app_design_system.dart';

/// 평평한 흰 카드: 흰색 채움, 테두리 `#EFEFF1` 1px, 모서리 16, 그림자 없음.
///
/// 콘텐츠는 유리가 아니라 이 카드 위에 둔다. 안쪽 [InkWell]이 물결을 그릴 수
/// 있도록 투명 [Material]을 깔아 둔다.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg + 2),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// 선택지 한 칸. 선택되면 연파랑 바탕에 파란 테두리 1.5, 아니면 흰 카드.
class AppChoiceTile extends StatelessWidget {
  const AppChoiceTile({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final Widget label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadii.md);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: selected ? AppColors.primarySoft : Colors.white,
        borderRadius: radius,
        border: selected
            ? Border.all(color: AppColors.primary, width: 1.5)
            : Border.all(color: AppColors.border),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: DefaultTextStyle.merge(
              style: const TextStyle(
                color: AppColors.text,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
              child: Center(child: label),
            ),
          ),
        ),
      ),
    );
  }
}

/// 연파랑 원 안에 파란 아이콘 하나.
class AppGlyph extends StatelessWidget {
  const AppGlyph({
    super.key,
    required this.icon,
    this.size = 44,
  });

  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: AppColors.primarySoft,
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Icon(icon, size: size * 0.45, color: AppColors.primary),
        ),
      ),
    );
  }
}

/// 글리프 + 제목 + 부제 한 줄짜리 흰 카드.
class AppInfoRow extends StatelessWidget {
  const AppInfoRow({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          AppGlyph(icon: icon, size: 40),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppColors.textSub,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
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

/// 평평한 색 알약: 자기 색 12% 바탕에 자기 색 글씨. 테두리와 그림자는 없다.
class TagChip extends StatelessWidget {
  const TagChip(
    this.label, {
    super.key,
    this.color = AppColors.primary,
    this.compact = false,
  });

  final String label;
  final Color color;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: compact ? 11 : 12,
          fontWeight: compact ? FontWeight.w600 : FontWeight.w700,
          height: compact ? 1.2 : null,
        ),
      ),
    );
  }
}
