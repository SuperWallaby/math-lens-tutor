import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_design_system.dart';

enum GlassTone { clear, blue, sunken }

const Color _kField = Color(0xFFEEF1F5);
const Color _kInk = Color(0xFF2C2C2C);

/// iOS Liquid Glass: real backdrop blur, translucent fill, rim + soft lift.
class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg + 2),
    this.borderRadius,
    this.tone = GlassTone.clear,
    this.opacity = 0.22,
    this.tint = const Color(0xFFD5E4F4),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final BorderRadius? borderRadius;
  final GlassTone tone;
  final double opacity;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(26);
    return _GlassSurface(
      tone: tone,
      borderRadius: radius,
      fillOpacity: opacity,
      child: Padding(padding: padding, child: child),
    );
  }
}

class _GlassSurface extends StatelessWidget {
  const _GlassSurface({
    required this.child,
    required this.tone,
    required this.borderRadius,
    this.tight = false,
    this.expand = true,
    this.fillOpacity,
  });

  final Widget child;
  final GlassTone tone;
  final BorderRadius borderRadius;
  final bool tight;
  final bool expand;
  final double? fillOpacity;

  double get _sigma => tight
      ? (tone == GlassTone.sunken ? 14 : 22)
      : (tone == GlassTone.sunken ? 22 : 40);

  double get _fillAlpha {
    if (fillOpacity != null) return fillOpacity!;
    return switch (tone) {
      GlassTone.blue => 0.24,
      GlassTone.sunken => 0.16,
      GlassTone.clear => 0.20,
    };
  }

  ImageFilter get _frost =>
      ImageFilter.blur(sigmaX: _sigma, sigmaY: _sigma, tileMode: TileMode.clamp);

  @override
  Widget build(BuildContext context) {
    final rim = switch (tone) {
      GlassTone.sunken => const Color(0x66FFFFFF),
      _ => const Color(0xE8FFFFFF),
    };
    final sheen = switch (tone) {
      GlassTone.blue => LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFFB7D4F0).withValues(alpha: _fillAlpha + 0.04),
            const Color(0xFF8EB4D8).withValues(alpha: _fillAlpha * 0.35),
          ],
        ),
      GlassTone.sunken => LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: _fillAlpha),
            Colors.white.withValues(alpha: _fillAlpha * 0.25),
          ],
        ),
      GlassTone.clear => LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: _fillAlpha + 0.03),
            Colors.white.withValues(alpha: _fillAlpha * 0.22),
          ],
        ),
    };

    final shadows = tight
        ? switch (tone) {
            GlassTone.sunken => const [
                BoxShadow(
                  color: Color(0x55A8B4C4),
                  offset: Offset(2, 2),
                  blurRadius: 5,
                  blurStyle: BlurStyle.inner,
                ),
                BoxShadow(
                  color: Color(0xAAFFFFFF),
                  offset: Offset(-1.5, -1.5),
                  blurRadius: 3,
                  blurStyle: BlurStyle.inner,
                ),
              ],
            _ => const [
                BoxShadow(
                  color: Color(0x33000000),
                  offset: Offset(0, 6),
                  blurRadius: 14,
                ),
                BoxShadow(
                  color: Color(0x66FFFFFF),
                  offset: Offset(0, -1),
                  blurRadius: 2,
                ),
              ],
          }
        : switch (tone) {
            GlassTone.sunken => const [
                BoxShadow(
                  color: Color(0x66A8B4C4),
                  offset: Offset(4, 4),
                  blurRadius: 10,
                  blurStyle: BlurStyle.inner,
                ),
                BoxShadow(
                  color: Color(0xCCFFFFFF),
                  offset: Offset(-3, -3),
                  blurRadius: 8,
                  blurStyle: BlurStyle.inner,
                ),
              ],
            _ => const [
                BoxShadow(
                  color: Color(0x3D000000),
                  offset: Offset(0, 18),
                  blurRadius: 36,
                  spreadRadius: -6,
                ),
                BoxShadow(
                  color: Color(0x1A000000),
                  offset: Offset(0, 4),
                  blurRadius: 10,
                ),
                BoxShadow(
                  color: Color(0x99FFFFFF),
                  offset: Offset(0, 0.6),
                  blurRadius: 0.6,
                ),
              ],
          };

    // HtmlElementView(CSS glass) can leave Flutter web stuck on the loader.
    // Use BackdropFilter on every platform so first frame actually paints.
    final frosted = ClipRRect(
      borderRadius: borderRadius,
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          Positioned.fill(
            child: BackdropFilter(
              filter: _frost,
              child: const ColoredBox(color: Color(0x00FFFFFF)),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: sheen,
                borderRadius: borderRadius,
                border: Border.all(color: rim, width: 1.15),
              ),
            ),
          ),
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 28,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x66FFFFFF), Color(0x00FFFFFF)],
                  ),
                ),
              ),
            ),
          ),
          Material(
            type: MaterialType.transparency,
            borderRadius: borderRadius,
            child: child,
          ),
        ],
      ),
    );

    return Container(
      width: expand ? double.infinity : null,
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: shadows,
      ),
      child: frosted,
    );
  }
}

/// One recessed glass well + one translucent glyph. Never nest another icon.
class GlassGlyph extends StatelessWidget {
  const GlassGlyph({
    super.key,
    required this.icon,
    this.size = 34,
    this.iconSize = 17,
    this.tint = GlassTone.sunken,
  });

  final IconData icon;
  final double size;
  final double iconSize;
  final GlassTone tint;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: _GlassSurface(
        tone: tint,
        tight: true,
        expand: false,
        borderRadius: BorderRadius.circular(size / 2),
        child: Center(
          child: Icon(
            icon,
            size: iconSize,
            color: _kInk.withValues(alpha: 0.42),
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
    return GlassPanel(
      tone: GlassTone.sunken,
      padding: padding,
      borderRadius: borderRadius ?? BorderRadius.circular(AppRadii.pill),
      child: child,
    );
  }
}

/// Quiet classroom light — just enough wash for frost, no busy wallpaper.
class GlassAtmosphere extends StatelessWidget {
  const GlassAtmosphere({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: _kField),
        const Positioned(
          top: -160,
          left: -80,
          child: IgnorePointer(
            child: SizedBox(
              width: 420,
              height: 420,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [Color(0x66C5D6E8), Color(0x00EEF1F5)],
                  ),
                ),
              ),
            ),
          ),
        ),
        const Positioned(
          right: -120,
          bottom: -80,
          child: IgnorePointer(
            child: SizedBox(
              width: 380,
              height: 380,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [Color(0x4DD4DCE6), Color(0x00EEF1F5)],
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
        opacity: 0.14,
        borderRadius: BorderRadius.circular(AppRadii.pill),
        child: child,
      ),
    );
  }
}

class GlassTabBar extends StatelessWidget {
  const GlassTabBar({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onSelected,
    this.icons,
    this.badgeIndex,
    this.badgeCount = 0,
  });

  final List<String> labels;
  final List<IconData>? icons;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final int? badgeIndex;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    return GlassNavBar(
      child: SizedBox(
        height: icons == null ? 56 : 64,
        child: Row(
          children: [
            for (var i = 0; i < labels.length; i++)
              Expanded(child: _tabCell(i)),
          ],
        ),
      ),
    );
  }

  Widget _tabCell(int i) {
    final selected = i == selectedIndex;
    final showBadge = badgeIndex == i && badgeCount > 0;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onSelected(i),
          borderRadius: BorderRadius.circular(AppRadii.pill),
          child: selected
              ? _GlassSurface(
                  tone: GlassTone.blue,
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                  child: _tabLabel(i, showBadge: showBadge),
                )
              : _tabLabel(i, showBadge: showBadge),
        ),
      ),
    );
  }

  Widget _tabLabel(int i, {required bool showBadge}) {
    final icon = icons != null && i < icons!.length ? icons![i] : null;
    final selected = i == selectedIndex;
    return Stack(
      alignment: Alignment.center,
      children: [
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null)
                Icon(
                  icon,
                  size: 18,
                  color: _kInk.withValues(alpha: selected ? 0.72 : 0.40),
                ),
              if (icon != null) const SizedBox(height: 2),
              Text(
                labels[i],
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: _kInk.withValues(alpha: selected ? 0.88 : 0.55),
                  fontSize: icon == null ? 13 : 10,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        if (showBadge)
          Positioned(
            top: 2,
            right: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: const BoxDecoration(
                color: Color(0xFF5E8FBF),
                borderRadius: BorderRadius.all(Radius.circular(999)),
              ),
              child: Text(
                '$badgeCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: radius,
        child: _GlassSurface(
          tone: primary ? GlassTone.blue : GlassTone.clear,
          borderRadius: radius,
          fillOpacity: primary ? 0.26 : 0.18,
          child: SizedBox(
            height: AppSizes.buttonHeight,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(
                    icon,
                    size: 18,
                    color: _kInk.withValues(alpha: 0.45),
                    shadows: const [
                      Shadow(
                        color: Color(0x66FFFFFF),
                        offset: Offset(0, 1),
                        blurRadius: 2,
                      ),
                    ],
                  ),
                  const SizedBox(width: 8),
                ],
                Text(
                  label,
                  style: TextStyle(
                    color: _kInk.withValues(alpha: 0.88),
                    fontSize: AppTypography.button,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class GlassField extends StatelessWidget {
  const GlassField({
    super.key,
    required this.hint,
    required this.icon,
    this.controller,
    this.focusNode,
    this.obscureText = false,
    this.keyboardType,
    this.enabled = true,
    this.onSubmitted,
  });

  final String hint;
  final IconData icon;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final bool obscureText;
  final TextInputType? keyboardType;
  final bool enabled;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      tone: GlassTone.sunken,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      borderRadius: BorderRadius.circular(AppRadii.pill),
      child: SizedBox(
        height: AppSizes.buttonHeight,
        child: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: _kInk.withValues(alpha: 0.40),
              shadows: const [
                Shadow(
                  color: Color(0x66FFFFFF),
                  offset: Offset(0, 1),
                  blurRadius: 2,
                ),
              ],
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                obscureText: obscureText,
                keyboardType: keyboardType,
                enabled: enabled,
                onSubmitted: onSubmitted,
                style: const TextStyle(
                  color: AppColors.text,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
                decoration: InputDecoration(
                  hintText: hint,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                  hintStyle: TextStyle(
                    color: _kInk.withValues(alpha: 0.38),
                    fontWeight: FontWeight.w500,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class GlassChoice extends StatelessWidget {
  const GlassChoice({
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
    final radius = BorderRadius.circular(AppRadii.pill);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: _GlassSurface(
          tone: selected ? GlassTone.blue : GlassTone.clear,
          borderRadius: radius,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: DefaultTextStyle.merge(
              style: TextStyle(
                color: _kInk.withValues(alpha: 0.88),
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

class GlassInfoRow extends StatelessWidget {
  const GlassInfoRow({
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
    return GlassPanel(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      borderRadius: BorderRadius.circular(AppRadii.pill),
      child: Row(
        children: [
          GlassGlyph(
            icon: icon,
            size: 40,
            iconSize: 18,
            tint: GlassTone.blue,
          ),
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

class GlassCircleButton extends StatelessWidget {
  const GlassCircleButton({
    super.key,
    required this.icon,
    required this.onPressed,
  });

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 44,
      height: 44,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),
          child: GlassGlyph(icon: icon, size: 44, iconSize: 20),
        ),
      ),
    );
  }
}
