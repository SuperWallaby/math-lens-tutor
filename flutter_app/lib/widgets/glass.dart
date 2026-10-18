import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';

import '../theme/app_design_system.dart';

/// 평평한 옅은 안개색 바탕. 떠 있는 유리가 이 위의 콘텐츠를 비춰 보이게 한다.
class GlassAtmosphere extends StatelessWidget {
  const GlassAtmosphere({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.background,
      child: SizedBox.expand(child: child),
    );
  }
}

/// 떠 있는 맑은 유리 알약 탭바. 높이 64, 좌우 12, 아래 16 + 안전 영역.
///
/// [onCenterAction]이 있으면 가운데(`labels.length ~/ 2`)에 파란 유리 카메라가
/// 30px 솟아오른다. 이때 [labels]는 짝수 개여야 하고, [selectedIndex]와
/// [onSelected]의 번호는 카메라를 뺀 탭 번호다.
///
/// 위젯 높이에 카메라 솟음이 들어 있어서 `Scaffold(extendBody: true)`가
/// 본문 아래 여백을 정확히 계산한다. 빈 영역은 터치를 통과시킨다.
class GlassTabBar extends StatelessWidget {
  GlassTabBar({
    super.key,
    required this.labels,
    required this.icons,
    required this.selectedIndex,
    required this.onSelected,
    this.onCenterAction,
    this.badgeIndex,
    this.badgeCount = 0,
  }) : assert(labels.length == icons.length),
       assert(
         onCenterAction == null || labels.length.isEven,
         'A center action needs an even number of tabs.',
       );

  final List<String> labels;
  final List<IconData> icons;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final VoidCallback? onCenterAction;
  final int? badgeIndex;
  final int badgeCount;

  static const double _barHeight = 64;
  static const double _sideInset = 12;
  static const double _bottomInset = 16;
  static const double _cameraSize = 58;
  static const double _cameraLift = 30;
  static const double _cameraRing = 3;
  static const double _cameraSlotWidth = 64;

  @override
  Widget build(BuildContext context) {
    final hasCamera = onCenterAction != null;
    final lift = hasCamera ? _cameraLift : 0.0;
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        _sideInset,
        0,
        _sideInset,
        _bottomInset + safeBottom,
      ),
      child: SizedBox(
        height: lift + _barHeight,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: _barHeight,
              child: GlassSurface(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: _slots(),
                ),
              ),
            ),
            if (hasCamera)
              Positioned.fill(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: SizedBox(
                    width: _cameraSlotWidth,
                    child: _cameraCell(onCenterAction!),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// 알약 안 칸들. 카메라 칸은 자리만 비워 두고, 카메라는 그 위에 따로 그린다.
  List<Widget> _slots() {
    final cameraAt = onCenterAction == null ? null : labels.length ~/ 2;
    return [
      for (var i = 0; i < labels.length; i++) ...[
        if (i == cameraAt) const SizedBox(width: _cameraSlotWidth),
        Expanded(child: _tabCell(i)),
      ],
    ];
  }

  Widget _tabCell(int i) {
    final selected = i == selectedIndex;
    final showBadge = badgeIndex == i && badgeCount > 0;
    final color = selected ? AppColors.primary : AppColors.textSub;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Semantics(
        button: true,
        selected: selected,
        onTap: () => onSelected(i),
        child: Ink(
          decoration: selected
              ? BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: _kPillRadius,
                )
              : null,
          child: InkWell(
            onTap: () => onSelected(i),
            borderRadius: _kPillRadius,
            excludeFromSemantics: true,
            child: Stack(
              alignment: Alignment.center,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icons[i], size: 22, color: color),
                      const SizedBox(height: 2),
                      Text(
                        labels[i],
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        style: TextStyle(
                          color: color,
                          fontSize: 10,
                          fontWeight: selected
                              ? FontWeight.w800
                              : FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (showBadge)
                  Positioned(
                    top: 0,
                    right: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1,
                      ),
                      decoration: const BoxDecoration(
                        color: AppColors.primaryDark,
                        borderRadius: _kPillRadius,
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
            ),
          ),
        ),
      ),
    );
  }

  /// 파란 유리 원(흰 테두리 3px) + 아래 「찍기」. 원 위쪽이 알약보다 30px 솟는다.
  Widget _cameraCell(VoidCallback onTap) {
    // 화면 낭독기에는 「찍기」 버튼 하나만 보인다. 안쪽 InkWell, 글자, 글자 칸
    // GestureDetector의 의미는 모두 이 노드로 대신한다.
    return Semantics(
      button: true,
      label: '찍기',
      onTap: onTap,
      excludeSemantics: true,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: 0,
            left: (_cameraSlotWidth - _cameraSize) / 2,
            width: _cameraSize,
            height: _cameraSize,
            child: DecoratedBox(
              position: DecorationPosition.foreground,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                border: Border.fromBorderSide(
                  BorderSide(color: Colors.white, width: _cameraRing),
                ),
              ),
              child: GlassSurface(
                preset: GlassPreset.prominent,
                child: InkWell(
                  onTap: onTap,
                  customBorder: const CircleBorder(),
                  splashColor: const Color(0x33FFFFFF),
                  highlightColor: const Color(0x1AFFFFFF),
                  excludeFromSemantics: true,
                  child: const Center(
                    child: Icon(
                      Icons.photo_camera_rounded,
                      size: 26,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: _cameraSize,
            bottom: 0,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onTap,
              child: const Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: EdgeInsets.only(bottom: 14),
                  child: Text(
                    '찍기',
                    maxLines: 1,
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 사진 위에 떠 있는 맑은 유리 동그라미 버튼 (44 x 44).
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
      child: GlassSurface(
        child: InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),
          child: Center(child: Icon(icon, size: 20, color: AppColors.text)),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 떠 있는 층: 탭바, 카메라, 흐림 가장자리, 시트, 팝업, 사진 위 라벨에만 쓴다.
// 콘텐츠는 흰 카드. 아래 위젯들은 GlassPreset / GlassSpec(app_design_system)을 따른다.
// ---------------------------------------------------------------------------

const BorderRadius _kPillRadius = BorderRadius.all(Radius.circular(AppRadii.pill));

/// 맑은 유리의 채도 1.8배 (CSS `saturate(1.8)`와 같은 행렬).
ColorFilter _saturation(double s) {
  return ColorFilter.matrix(<double>[
    0.213 + 0.787 * s, 0.715 - 0.715 * s, 0.072 - 0.072 * s, 0, 0, //
    0.213 - 0.213 * s, 0.715 + 0.285 * s, 0.072 - 0.072 * s, 0, 0, //
    0.213 - 0.213 * s, 0.715 - 0.715 * s, 0.072 + 0.928 * s, 0, 0, //
    0, 0, 0, 1, 0,
  ]);
}

ImageFilter _glassFilter(GlassPreset preset, double blur) {
  final blurFilter = ImageFilter.blur(
    sigmaX: blur,
    sigmaY: blur,
    tileMode: TileMode.clamp,
  );
  if (preset != GlassPreset.clear) return blurFilter;
  return ImageFilter.compose(outer: blurFilter, inner: _saturation(1.8));
}

/// 떠 있는 유리 한 장: 그림자 → 둥근 클립 → 뒷배경 흐림 → 채움 + 1px 테두리.
class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    required this.child,
    this.preset = GlassPreset.clear,
    this.borderRadius = _kPillRadius,
    this.padding = EdgeInsets.zero,
  });

  final Widget child;
  final GlassPreset preset;
  final BorderRadius borderRadius;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final spec = GlassSpec.of(preset);
    return CustomPaint(
      painter: _GlassShadowPainter(
        shadows: spec.shadows,
        borderRadius: borderRadius,
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: BackdropFilter(
          filter: _glassFilter(preset, spec.blur),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: spec.fill,
              borderRadius: borderRadius,
              border: Border.all(color: spec.rim),
            ),
            child: Stack(
              fit: StackFit.passthrough,
              children: [
                Material(
                  type: MaterialType.transparency,
                  child: Padding(padding: padding, child: child),
                ),
                if (spec.topHighlight)
                  const Positioned(
                    top: 1,
                    left: 1,
                    right: 1,
                    height: 2,
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color(0xE6FFFFFF), Color(0x00FFFFFF)],
                          ),
                        ),
                      ),
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

/// 유리 바깥에만 그림자를 그린다. `BoxShadow`를 그대로 쓰면 반투명 유리 안쪽까지
/// 그림자가 비쳐 탁해 보이므로, 도형 안쪽은 잘라낸다(CSS box-shadow와 같은 동작).
class _GlassShadowPainter extends CustomPainter {
  const _GlassShadowPainter({
    required this.shadows,
    required this.borderRadius,
  });

  final List<BoxShadow> shadows;
  final BorderRadius borderRadius;

  @override
  void paint(Canvas canvas, Size size) {
    if (shadows.isEmpty) return;
    final shape = borderRadius.toRRect(Offset.zero & size);
    var reach = 0.0;
    for (final s in shadows) {
      reach = math.max(
        reach,
        s.offset.distance + s.blurRadius * 2 + s.spreadRadius.abs(),
      );
    }
    final outside = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect((Offset.zero & size).inflate(reach))
      ..addRRect(shape);
    canvas.save();
    canvas.clipPath(outside);
    for (final s in shadows) {
      canvas.drawRRect(
        shape.shift(s.offset).inflate(s.spreadRadius),
        s.toPaint(),
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_GlassShadowPainter old) =>
      !listEquals(old.shadows, shadows) || old.borderRadius != borderRadius;
}

/// 파란 유리 알약 버튼. 높이 52, 흰 글씨 16/700. `onPressed`가 null이면 비활성.
class GlassPrimaryButton extends StatelessWidget {
  const GlassPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Semantics(
      button: true,
      enabled: enabled,
      onTap: onPressed,
      child: Opacity(
        opacity: enabled ? 1 : 0.4,
        child: GlassSurface(
          preset: GlassPreset.prominent,
          child: InkWell(
            onTap: onPressed,
            borderRadius: _kPillRadius,
            splashColor: const Color(0x33FFFFFF),
            highlightColor: const Color(0x1AFFFFFF),
            excludeFromSemantics: true,
            child: SizedBox(
              height: AppSizes.buttonHeight,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (icon != null) ...[
                      Icon(icon, size: 20, color: Colors.white),
                      const SizedBox(width: 8),
                    ],
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 맑은 유리 말풍선. 아래 가운데에 작은 꼬리가 붙는다.
class GlassCoachBubble extends StatelessWidget {
  const GlassCoachBubble({super.key, required this.text});

  final String text;

  static const _tailWidth = 14.0;
  static const _tailHeight = 7.0;

  @override
  Widget build(BuildContext context) {
    final spec = GlassSpec.of(GlassPreset.clear);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GlassSurface(
          borderRadius: BorderRadius.circular(14),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.text,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        // 말풍선 아랫 테두리 위로 1px 겹쳐 꼬리와 이어 보이게 한다.
        Transform.translate(
          offset: const Offset(0, -1),
          child: CustomPaint(
            size: const Size(_tailWidth, _tailHeight),
            painter: _BubbleTailPainter(fill: spec.fill, rim: spec.rim),
          ),
        ),
      ],
    );
  }
}

class _BubbleTailPainter extends CustomPainter {
  const _BubbleTailPainter({required this.fill, required this.rim});

  final Color fill;
  final Color rim;

  @override
  void paint(Canvas canvas, Size size) {
    final tail = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width, 0);
    canvas.drawPath(Path.from(tail)..close(), Paint()..color = fill);
    canvas.drawPath(
      tail,
      Paint()
        ..color = rim
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_BubbleTailPainter old) =>
      old.fill != fill || old.rim != rim;
}

/// 스크롤하면 나타나는 위쪽 흐림 가장자리 + 가운데 작은 제목.
/// 위는 `#EEF3F8` 82%에서 아래로 0까지 사라진다. 터치는 통과시킨다.
class GlassScrollEdge extends StatelessWidget {
  const GlassScrollEdge({
    super.key,
    required this.visible,
    required this.title,
  });

  final bool visible;
  final String title;

  static const height = 84.0;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    return IgnorePointer(
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: const Duration(milliseconds: 200),
        child: SizedBox(
          height: height,
          child: ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: 10,
                sigmaY: 10,
                tileMode: TileMode.clamp,
              ),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppColors.background.withValues(alpha: 0.82),
                      AppColors.background.withValues(alpha: 0),
                    ],
                  ),
                ),
                child: Material(
                  type: MaterialType.transparency,
                  child: Column(
                    children: [
                      SizedBox(height: topInset),
                      Expanded(
                        child: Center(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.text,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 위쪽 모서리 26의 맑은 유리 시트를 띄운다.
///
/// [showModalBottomSheet]에 투명 배경과 그림자 0을 주고, 내용을
/// `GlassSurface(clear)` 안에 넣는다. 시트는 콘텐츠 위에 떠 있으므로 유리다.
/// [showDragHandle]이 참이면 유리 안쪽 위에 손잡이를 그린다(내용이 스스로
/// 손잡이를 그리면 끈다). [isScrollControlled]는 그대로 넘긴다.
Future<T?> showGlassSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = false,
  bool showDragHandle = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    backgroundColor: Colors.transparent,
    elevation: 0,
    builder: (sheetContext) {
      return GlassSurface(
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadii.lg),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (showDragHandle) const _GlassSheetHandle(),
            Flexible(child: builder(sheetContext)),
          ],
        ),
      );
    },
  );
}

class _GlassSheetHandle extends StatelessWidget {
  const _GlassSheetHandle();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: Center(
        child: Container(
          width: 36,
          height: 4,
          decoration: BoxDecoration(
            color: AppColors.textMuted.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }
}

/// 모서리 26의 맑은 유리 팝업. [AlertDialog]와 같은 [title], [content],
/// [actions]를 받는다. [showDialog]의 builder 안에서 쓴다.
class GlassDialog extends StatelessWidget {
  const GlassDialog({super.key, this.title, this.content, this.actions});

  final Widget? title;
  final Widget? content;
  final List<Widget>? actions;

  // 글꼴은 테마 textTheme 에서만 오므로 직접 적어 두고, 아래에서는
  // DefaultTextStyle.merge 로 상속된 스타일 위에 얹는다.
  static const _titleStyle = TextStyle(
    fontFamily: AppFonts.family,
    color: AppColors.text,
    fontSize: 20,
    fontWeight: FontWeight.w800,
    height: 1.25,
  );

  static const _contentStyle = TextStyle(
    fontFamily: AppFonts.family,
    color: AppColors.textSub,
    fontSize: 15,
    fontWeight: FontWeight.w500,
    height: 1.5,
  );

  /// 테마 버튼은 최소 폭이 무한대라 팝업 안에서 한 줄에 못 놓이고 세로로 쌓인다.
  /// 팝업 안에서만 최소 크기를 64 x 44로 낮춰 버튼들이 나란히 서게 한다.
  static Widget _compactButtons(BuildContext context, Widget child) {
    final theme = Theme.of(context);
    ButtonStyle compact(ButtonStyle? base) => (base ?? const ButtonStyle())
        .copyWith(minimumSize: const WidgetStatePropertyAll(Size(64, 44)));
    return Theme(
      data: theme.copyWith(
        filledButtonTheme: FilledButtonThemeData(
          style: compact(theme.filledButtonTheme.style),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: compact(theme.outlinedButtonTheme.style),
        ),
        // 맑은 유리 위에서 기본 파랑(primary)은 대비가 모자라 진한 파랑으로 쓴다.
        textButtonTheme: TextButtonThemeData(
          style: compact(theme.textButtonTheme.style).merge(
            TextButton.styleFrom(foregroundColor: AppColors.primaryDark),
          ),
        ),
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 280, maxWidth: 560),
        child: GlassSurface(
          borderRadius: BorderRadius.circular(AppRadii.lg),
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          child: IntrinsicWidth(
            stepWidth: 56,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (title != null)
                  Padding(
                    padding: EdgeInsets.only(bottom: content != null ? 12 : 8),
                    child: DefaultTextStyle.merge(
                      style: _titleStyle,
                      child: title!,
                    ),
                  ),
                if (content != null)
                  Flexible(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: DefaultTextStyle.merge(
                        style: _contentStyle,
                        child: content!,
                      ),
                    ),
                  ),
                if (actions != null && actions!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: _compactButtons(
                      context,
                      OverflowBar(
                        alignment: MainAxisAlignment.end,
                        spacing: 8,
                        overflowSpacing: 8,
                        overflowAlignment: OverflowBarAlignment.end,
                        children: actions!,
                      ),
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
