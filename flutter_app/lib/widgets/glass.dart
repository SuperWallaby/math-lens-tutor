import 'package:flutter/material.dart';

import '../theme/app_design_system.dart';

enum GlassTone { clear, blue, sunken }

/// Pin 3D glass: top-left light + bottom-right shade. No face gradient.
class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg + 2),
    this.borderRadius,
    this.tone = GlassTone.clear,
    this.opacity = 0.34,
    this.tint = const Color(0xFFD5E4F4),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final BorderRadius? borderRadius;
  final GlassTone tone;

  /// Kept for call-site compatibility. Visuals come from [tone].
  final double opacity;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(26);
    return _GlassSurface(
      tone: tone,
      borderRadius: radius,
      child: Padding(padding: padding, child: child),
    );
  }
}

class _GlassSurface extends StatelessWidget {
  const _GlassSurface({
    required this.child,
    required this.tone,
    required this.borderRadius,
  });

  final Widget child;
  final GlassTone tone;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    final fill = switch (tone) {
      GlassTone.blue => const Color(0x9EB7D4F0),
      GlassTone.sunken => const Color(0x38FFFFFF),
      GlassTone.clear => const Color(0x61FFFFFF),
    };
    final border = switch (tone) {
      GlassTone.sunken => const Color(0x73FFFFFF),
      GlassTone.blue => const Color(0xE6FFFFFF),
      GlassTone.clear => const Color(0xEBFFFFFF),
    };
    final shadows = switch (tone) {
      GlassTone.blue => const [
          BoxShadow(
            color: Color(0xFFC2CAD6),
            offset: Offset(10, 10),
            blurRadius: 20,
          ),
          BoxShadow(
            color: Color(0xFFFFFFFF),
            offset: Offset(-7, -7),
            blurRadius: 14,
          ),
          BoxShadow(
            color: Color(0x387EAFD9),
            offset: Offset(0, 10),
            blurRadius: 18,
          ),
          BoxShadow(
            color: Color(0xEBFFFFFF),
            offset: Offset(0, 1),
            blurRadius: 1,
            blurStyle: BlurStyle.inner,
          ),
          BoxShadow(
            color: Color(0x1F5E8FBF),
            offset: Offset(0, -1),
            blurRadius: 1,
            blurStyle: BlurStyle.inner,
          ),
        ],
      GlassTone.sunken => const [
          BoxShadow(
            color: Color(0xFFC2CAD6),
            offset: Offset(7, 7),
            blurRadius: 14,
            blurStyle: BlurStyle.inner,
          ),
          BoxShadow(
            color: Color(0xFFFFFFFF),
            offset: Offset(-6, -6),
            blurRadius: 12,
            blurStyle: BlurStyle.inner,
          ),
        ],
      GlassTone.clear => const [
          BoxShadow(
            color: Color(0xFFC2CAD6),
            offset: Offset(10, 10),
            blurRadius: 20,
          ),
          BoxShadow(
            color: Color(0xFFFFFFFF),
            offset: Offset(-8, -8),
            blurRadius: 16,
          ),
          BoxShadow(
            color: Color(0xF2FFFFFF),
            offset: Offset(0, 1),
            blurRadius: 1,
            blurStyle: BlurStyle.inner,
          ),
          BoxShadow(
            color: Color(0x29A0ACBC),
            offset: Offset(0, -1),
            blurRadius: 1,
            blurStyle: BlurStyle.inner,
          ),
        ],
    };

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: borderRadius,
        border: Border.all(color: border, width: 1),
        boxShadow: shadows,
      ),
      child: Material(
        type: MaterialType.transparency,
        borderRadius: borderRadius,
        child: child,
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

class GlassAtmosphere extends StatelessWidget {
  const GlassAtmosphere({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: Color(0xFFE4E9F0)),
        const Positioned(
          top: -90,
          left: -70,
          child: IgnorePointer(
            child: SizedBox(
              width: 360,
              height: 360,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [Color(0xCCB7D4F0), Color(0x00E4E9F0)],
                  ),
                ),
              ),
            ),
          ),
        ),
        const Positioned(
          top: 220,
          right: -80,
          child: IgnorePointer(
            child: SizedBox(
              width: 260,
              height: 260,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [Color(0xAABFD8F0), Color(0x00E4E9F0)],
                  ),
                ),
              ),
            ),
          ),
        ),
        const Positioned(
          left: -40,
          bottom: 80,
          child: IgnorePointer(
            child: SizedBox(
              width: 220,
              height: 220,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [Color(0x99D0DCEC), Color(0x00E4E9F0)],
                  ),
                ),
              ),
            ),
          ),
        ),
        const Positioned(
          bottom: -110,
          right: -30,
          child: IgnorePointer(
            child: SizedBox(
              width: 300,
              height: 300,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [Color(0x99C4D0E4), Color(0x00E4E9F0)],
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

class GlassTabBar extends StatelessWidget {
  const GlassTabBar({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onSelected,
    this.badgeIndex,
    this.badgeCount = 0,
  });

  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final int? badgeIndex;
  final int badgeCount;

  Widget _tabLabel(int i) {
    return Center(
      child: Badge(
        isLabelVisible: badgeIndex == i && badgeCount > 0,
        label: Text('$badgeCount'),
        child: Text(
          labels[i],
          style: TextStyle(
            color: AppColors.text,
            fontSize: 13,
            fontWeight: i == selectedIndex ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GlassNavBar(
      child: SizedBox(
        height: 56,
        child: Row(
          children: [
            for (var i = 0; i < labels.length; i++) ...[
              if (i > 0)
                const SizedBox(
                  width: 1,
                  height: 22,
                  child: ColoredBox(color: Color(0x3390A0B0)),
                ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 5),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => onSelected(i),
                      borderRadius: BorderRadius.circular(AppRadii.pill),
                      child: i == selectedIndex
                          ? _GlassSurface(
                              tone: GlassTone.blue,
                              borderRadius:
                                  BorderRadius.circular(AppRadii.pill),
                              child: _tabLabel(i),
                            )
                          : _tabLabel(i),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
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
          child: SizedBox(
            height: AppSizes.buttonHeight,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 20, color: AppColors.onPrimarySoft),
                  const SizedBox(width: 8),
                ],
                Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.onPrimarySoft,
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
      padding: const EdgeInsets.symmetric(horizontal: 18),
      borderRadius: BorderRadius.circular(AppRadii.pill),
      child: SizedBox(
        height: AppSizes.buttonHeight,
        child: Row(
          children: [
            Icon(icon, size: 20, color: AppColors.textMuted),
            const SizedBox(width: 12),
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
                  hintStyle: const TextStyle(
                    color: AppColors.textMuted,
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
              style: const TextStyle(
                color: AppColors.text,
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
          SizedBox(
            width: 44,
            height: 44,
            child: _GlassSurface(
              tone: GlassTone.blue,
              borderRadius: BorderRadius.circular(22),
              child: Icon(icon, color: AppColors.primaryDark, size: 22),
            ),
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
          child: _GlassSurface(
            tone: GlassTone.clear,
            borderRadius: BorderRadius.circular(22),
            child: Icon(icon, size: 20, color: AppColors.text),
          ),
        ),
      ),
    );
  }
}
