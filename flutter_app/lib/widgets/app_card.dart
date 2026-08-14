import 'package:flutter/material.dart';

import '../theme/app_design_system.dart';
import 'glass.dart';

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
    return GlassPanel(
      padding: padding,
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
        color: Color.lerp(Colors.white, color, compact ? 0.18 : 0.22),
        borderRadius: BorderRadius.circular(AppRadii.pill),
        border: Border.all(color: const Color(0xE6FFFFFF), width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x147EAFD9),
            offset: Offset(0, 4),
            blurRadius: 10,
          ),
        ],
      ),
      child: Text(
        label,
        style: TextStyle(
          color: Color.lerp(color, AppColors.text, compact ? 0.25 : 0.15),
          fontSize: compact ? 11 : 12,
          fontWeight: compact ? FontWeight.w600 : FontWeight.w700,
          height: compact ? 1.2 : null,
        ),
      ),
    );
  }
}
