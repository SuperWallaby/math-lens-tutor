import 'package:flutter/material.dart';

import '../theme/app_design_system.dart';

/// Painted frosted glass. BackdropFilter is skipped — it does not show on Flutter web.
class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg + 2),
    this.borderRadius,
    this.opacity = 0.34,
    this.tint = const Color(0xFFD5E4F4),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final BorderRadius? borderRadius;
  final double opacity;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(22);
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            offset: Offset(0, 12),
            blurRadius: 22,
          ),
          BoxShadow(
            color: Color(0x337EAFD9),
            offset: Offset(0, 6),
            blurRadius: 16,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xF2FFFFFF),
                Color.lerp(Colors.white, tint, 0.45)!,
                const Color(0xE6FFFFFF),
              ],
            ),
            border: Border.all(color: const Color(0xF2FFFFFF), width: 1.4),
          ),
          child: Stack(
            children: [
              const Positioned(
                top: -30,
                left: -20,
                child: IgnorePointer(
                  child: SizedBox(
                    width: 160,
                    height: 90,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          colors: [Color(0xCCFFFFFF), Color(0x00FFFFFF)],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Padding(padding: padding, child: child),
            ],
          ),
        ),
      ),
    );
  }
}

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
        color: const Color(0xB3FFFFFF),
        borderRadius: radius,
        border: Border.all(color: const Color(0xE6FFFFFF), width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            offset: Offset(0, 4),
            blurRadius: 10,
          ),
        ],
      ),
      child: child,
    );
  }
}

class GlassAtmosphere extends StatelessWidget {
  const GlassAtmosphere({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: Color(0xFFE8EDF3)),
        const Positioned(
          top: -80,
          left: -60,
          child: IgnorePointer(
            child: SizedBox(
              width: 320,
              height: 320,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [Color(0x88C9DCF0), Color(0x00E8EDF3)],
                  ),
                ),
              ),
            ),
          ),
        ),
        const Positioned(
          bottom: -100,
          right: -40,
          child: IgnorePointer(
            child: SizedBox(
              width: 280,
              height: 280,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [Color(0x55D5DDEA), Color(0x00E8EDF3)],
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

class GlassNavBar extends StatelessWidget {
  const GlassNavBar({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: GlassPanel(
        padding: EdgeInsets.zero,
        borderRadius: BorderRadius.circular(AppRadii.pill),
        child: child,
      ),
    );
  }
}

/// Pin-style glass pill button.
class GlassButton extends StatelessWidget {
  const GlassButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.primary = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadii.pill);
    final fg = AppColors.onPrimarySoft;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: radius,
        child: Ink(
          height: AppSizes.buttonHeight,
          decoration: BoxDecoration(
            borderRadius: radius,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: primary
                  ? const [Color(0xFFC5DDF2), Color(0xFF9EC4EA)]
                  : const [Color(0xF5FFFFFF), Color(0xE6F3F6FA)],
            ),
            border: Border.all(color: const Color(0xF2FFFFFF), width: 1.3),
            boxShadow: [
              BoxShadow(
                color: primary
                    ? const Color(0x667EAFD9)
                    : const Color(0x1A000000),
                offset: const Offset(0, 8),
                blurRadius: 16,
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 20, color: fg),
                const SizedBox(width: 8),
              ],
              Text(
                label,
                style: TextStyle(
                  color: fg,
                  fontSize: AppTypography.button,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
