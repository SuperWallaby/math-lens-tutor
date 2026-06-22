import 'package:flutter/material.dart';

import '../theme/app_design_system.dart';

/// 로딩 플레이스홀더 — 넓고 은은한 좌→右 shimmer.
class SkeletonBox extends StatefulWidget {
  const SkeletonBox({
    super.key,
    this.width,
    this.height = 16,
    this.borderRadius = 999,
    this.tint = SkeletonTint.neutral,
  });

  final double? width;
  final double height;
  final double borderRadius;
  final SkeletonTint tint;

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

enum SkeletonTint { neutral, error }

class _SkeletonBoxState extends State<SkeletonBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        final begin = Alignment(-1.6 + 3.2 * t, 0);
        final end = Alignment(0.4 + 3.2 * t, 0);

        final List<Color> colors;
        final List<double> stops;
        switch (widget.tint) {
          case SkeletonTint.neutral:
            colors = [
              AppColors.surfaceMuted.withValues(alpha: 0.55),
              AppColors.surfaceMuted.withValues(alpha: 0.7),
              AppColors.surfaceElevated,
              AppColors.surface,
              AppColors.surfaceElevated,
              AppColors.surfaceMuted.withValues(alpha: 0.7),
              AppColors.surfaceMuted.withValues(alpha: 0.55),
            ];
            stops = const [0.0, 0.22, 0.38, 0.5, 0.62, 0.78, 1.0];
          case SkeletonTint.error:
            colors = [
              AppColors.accent.withValues(alpha: 0.04),
              AppColors.accent.withValues(alpha: 0.05),
              AppColors.accent.withValues(alpha: 0.065),
              AppColors.accent.withValues(alpha: 0.09),
              AppColors.accent.withValues(alpha: 0.065),
              AppColors.accent.withValues(alpha: 0.05),
              AppColors.accent.withValues(alpha: 0.04),
            ];
            stops = const [0.0, 0.22, 0.38, 0.5, 0.62, 0.78, 1.0];
        }

        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            color: AppColors.surfaceMuted,
            gradient: LinearGradient(
              begin: begin,
              end: end,
              colors: colors,
              stops: stops,
            ),
          ),
        );
      },
    );
  }
}
