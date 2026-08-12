import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_design_system.dart';

/// 아이폰 폴더형 반투명 글래스 패널 (라이트 톤).
class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg + 2),
    this.borderRadius,
    this.opacity = 0.82,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final BorderRadius? borderRadius;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(AppRadii.lg);
    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          width: double.infinity,
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: opacity),
            borderRadius: radius,
            border: Border.all(
              color: AppColors.glassStroke,
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1A2A44).withValues(alpha: 0.10),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

/// 쿨그레이 바탕 + 은은한 빛 — 글래스가 돋보이게.
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
          top: -80,
          left: -60,
          child: _blob(const Color(0xFF9BB8E8), 280),
        ),
        Positioned(
          top: 140,
          right: -90,
          child: _blob(const Color(0xFFC5D0DE), 220),
        ),
        Positioned(
          bottom: -40,
          left: 40,
          child: _blob(const Color(0xFFB8C9E6), 260),
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
              color.withValues(alpha: 0.45),
              color.withValues(alpha: 0),
            ],
          ),
        ),
      ),
    );
  }
}
