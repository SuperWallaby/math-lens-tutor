import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_design_system.dart';

/// Frosted glass panel matching the approved Pinterest pin.
class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg + 2),
    this.borderRadius,
    this.opacity = 0.34,
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
              borderRadius: radius,
              border: Border.all(color: const Color(0xCCFFFFFF), width: 1.2),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: opacity + 0.18),
                  const Color(0xFFD7E6F5).withValues(alpha: opacity),
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
        color: const Color(0x59FFFFFF),
        borderRadius: radius,
        border: Border.all(color: const Color(0xB3FFFFFF)),
        boxShadow: AppShadows.sunken,
      ),
      child: child,
    );
  }
}

/// Light gray canvas with a faint blue wash so glass can frost.
class GlassAtmosphere extends StatelessWidget {
  const GlassAtmosphere({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: AppColors.background),
        const Positioned(
          top: -120,
          left: -80,
          child: IgnorePointer(
            child: SizedBox(
              width: 280,
              height: 280,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Color(0x66C5D9EE),
                      Color(0x00F0F0F0),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}

/// Floating frosted pill around a Material navigation bar.
class GlassNavBar extends StatelessWidget {
  const GlassNavBar({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: GlassPanel(
        padding: EdgeInsets.zero,
        opacity: 0.4,
        borderRadius: BorderRadius.circular(AppRadii.pill),
        child: child,
      ),
    );
  }
}
