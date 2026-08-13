import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_design_system.dart';

/// 레퍼런스 뉴모+글래스 — 들어올린 반투명 패널.
class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg + 2),
    this.borderRadius,
    this.opacity = 0.32,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final BorderRadius? borderRadius;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(AppRadii.lg);
    return Container(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: AppShadows.raised,
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            width: double.infinity,
            padding: padding,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: opacity),
              borderRadius: radius,
              border: Border.all(color: AppColors.glassStroke, width: 1),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: opacity + 0.12),
                  Colors.white.withValues(alpha: opacity),
                ],
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// 패인 입력·비선택 보기.
class GlassSunken extends StatelessWidget {
  const GlassSunken({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(
      horizontal: AppSpacing.lg,
      vertical: AppSpacing.md,
    ),
    this.borderRadius,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(AppRadii.pill);
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: const Color(0x2EFFFFFF),
        borderRadius: radius,
        border: Border.all(color: const Color(0x59FFFFFF)),
        boxShadow: AppShadows.sunken,
      ),
      child: child,
    );
  }
}

/// 연한 회색 바닥 + 아래쪽 보랏빛·분홍 글로우.
class GlassAtmosphere extends StatelessWidget {
  const GlassAtmosphere({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: AppColors.background),
        Positioned(
          top: -90,
          left: -70,
          child: _blob(const Color(0xFFC5D6EF), 300),
        ),
        Positioned(
          bottom: -80,
          left: -40,
          child: _blob(const Color(0xFFBAAAE6), 320),
        ),
        Positioned(
          bottom: -70,
          right: -50,
          child: _blob(const Color(0xFFE8B0D2), 300),
        ),
        child,
      ],
    );
  }

  static Widget _blob(Color color, double size) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color.withValues(alpha: 0.42),
              color.withValues(alpha: 0),
            ],
          ),
        ),
      ),
    );
  }
}
