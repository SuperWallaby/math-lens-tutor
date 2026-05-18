import 'package:flutter/material.dart';

/// 로딩 플레이스홀더 — 넓고 은은한 좌→우 shimmer.
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
        // 더 넓은 밴드가 지나가도록 이동 범위 확대
        final begin = Alignment(-1.6 + 3.2 * t, 0);
        final end = Alignment(0.4 + 3.2 * t, 0);

        final List<Color> colors;
        final List<double> stops;
        switch (widget.tint) {
          case SkeletonTint.neutral:
            colors = [
              Colors.white.withValues(alpha: 0.03),
              Colors.white.withValues(alpha: 0.04),
              Colors.white.withValues(alpha: 0.055),
              Colors.white.withValues(alpha: 0.075),
              Colors.white.withValues(alpha: 0.055),
              Colors.white.withValues(alpha: 0.04),
              Colors.white.withValues(alpha: 0.03),
            ];
            stops = const [0.0, 0.22, 0.38, 0.5, 0.62, 0.78, 1.0];
          case SkeletonTint.error:
            colors = [
              const Color(0xFFF87171).withValues(alpha: 0.04),
              const Color(0xFFF87171).withValues(alpha: 0.05),
              const Color(0xFFF87171).withValues(alpha: 0.065),
              const Color(0xFFF87171).withValues(alpha: 0.09),
              const Color(0xFFF87171).withValues(alpha: 0.065),
              const Color(0xFFF87171).withValues(alpha: 0.05),
              const Color(0xFFF87171).withValues(alpha: 0.04),
            ];
            stops = const [0.0, 0.22, 0.38, 0.5, 0.62, 0.78, 1.0];
        }

        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
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
