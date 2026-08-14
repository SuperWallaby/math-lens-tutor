import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_design_system.dart';

/// Soft frosted glass panel — light fill, thin rim, quiet drop shadow.
class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg + 2),
    this.borderRadius,
    this.opacity = 0.48,
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
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            width: double.infinity,
            padding: padding,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: opacity),
              borderRadius: radius,
              border: Border.all(color: AppColors.glassStroke),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Clear glass input / unselected choice.
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
        color: const Color(0x66FFFFFF),
        borderRadius: radius,
        border: Border.all(color: AppColors.glassStroke),
        boxShadow: AppShadows.sunken,
      ),
      child: child,
    );
  }
}

/// Flat light-gray canvas. No colored glow blobs.
class GlassAtmosphere extends StatelessWidget {
  const GlassAtmosphere({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.background,
      child: child,
    );
  }
}
