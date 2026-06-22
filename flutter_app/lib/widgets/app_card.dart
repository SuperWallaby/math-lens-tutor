import 'package:flutter/material.dart';

import '../theme/app_design_system.dart';

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
    final design = context.appDesign;
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: design.surface,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: design.border),
      ),
      child: child,
    );
  }
}

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
        color: color.withValues(alpha: compact ? 0.14 : 0.18),
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: Color.lerp(color, AppColors.text, compact ? 0.45 : 0.35),
          fontSize: compact ? 11 : 12,
          fontWeight: compact ? FontWeight.w600 : FontWeight.w700,
          height: compact ? 1.2 : null,
        ),
      ),
    );
  }
}
