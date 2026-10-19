import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_design_system.dart';
import 'glass.dart';

/// 하늘색 구간에서 흰 글자가 묻히지 않게 깔아 주는 옅은 남색 그림자.
const List<Shadow> kStageTextShadows = [
  Shadow(color: Color(0x591E46AA), offset: Offset(0, 1), blurRadius: 3),
];

/// 파란 무대 위 글자 스타일.
abstract final class StageText {
  /// 흰색 86% — 설명 줄.
  static const Color sub = Color(0xDBFFFFFF);

  /// 흰색 80% — 칸 라벨, 작은 머리말.
  static const Color muted = Color(0xCCFFFFFF);

  static const TextStyle title = TextStyle(
    shadows: kStageTextShadows,
    fontSize: 24,
    fontWeight: FontWeight.w700,
    height: 1.25,
    color: Colors.white,
  );

  static const TextStyle subtitle = TextStyle(
    shadows: kStageTextShadows,
    fontSize: 13.5,
    fontWeight: FontWeight.w600,
    height: 1.4,
    color: sub,
  );

  static const TextStyle eyebrow = TextStyle(
    fontSize: 12.5,
    fontWeight: FontWeight.w700,
    color: muted,
  );

  static const TextStyle body = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 1.45,
    color: Colors.white,
  );

  static const TextStyle cardTitle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w700,
    height: 1.35,
    color: Colors.white,
  );
}

/// 파란 무대 바탕: 165° 하늘색 → 코발트, 아래 모서리 32.
class StageBackground extends StatelessWidget {
  const StageBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: AppGradients.stage,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: child,
    );
  }
}

/// 무대 위 유리 한 장(무대용 유리).
class StageGlass extends StatelessWidget {
  const StageGlass({
    super.key,
    required this.child,
    this.borderRadius = const BorderRadius.all(Radius.circular(AppRadii.pill)),
    this.padding = EdgeInsets.zero,
  });

  final Widget child;
  final BorderRadius borderRadius;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return GlassSurface(
      preset: GlassPreset.onBlue,
      borderRadius: borderRadius,
      padding: padding,
      child: child,
    );
  }
}

/// 무대 위 카드: 요약과 흰 주 버튼을 담는다.
class StageCard extends StatelessWidget {
  const StageCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return StageGlass(
      borderRadius: BorderRadius.circular(AppRadii.lg),
      padding: padding,
      child: child,
    );
  }
}

/// 무대 위 숫자 칸: 라벨 + 큰 값.
class StageTile extends StatelessWidget {
  const StageTile({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    // 「정답률, 72%」처럼 이름과 값이 한 번에 읽히게 묶는다.
    return StageGlass(
      borderRadius: BorderRadius.circular(AppRadii.lg),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      child: MergeSemantics(
        child: Column(
          children: [
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: StageText.muted,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w800,
                height: 1.05,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 숫자 칸 여러 개를 같은 폭으로 나란히.
class StageTileRow extends StatelessWidget {
  const StageTileRow({super.key, required this.tiles});

  final List<StageTile> tiles;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < tiles.length; i++) ...[
          if (i > 0) const SizedBox(width: AppSpacing.md),
          Expanded(child: tiles[i]),
        ],
      ],
    );
  }
}

/// 무대 위 알약: 고른 것은 흰 바탕 + 진파랑 글자, 아닌 것은 유리 + 흰 글자.
class StagePill extends StatelessWidget {
  const StagePill({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  static const double height = 40;

  @override
  Widget build(BuildContext context) {
    const radius = BorderRadius.all(Radius.circular(AppRadii.pill));
    final text = Text(
      label,
      maxLines: 1,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: selected ? AppColors.primaryDark : Colors.white,
      ),
    );
    final content = InkWell(
      onTap: onTap,
      borderRadius: radius,
      child: SizedBox(
        height: height,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Center(widthFactor: 1, child: text),
        ),
      ),
    );
    // 학년 알약(GradeBandTabBar)처럼 선택 상태만 알린다.
    return Semantics(
      selected: selected,
      child: selected
          ? Material(color: Colors.white, borderRadius: radius, child: content)
          : StageGlass(borderRadius: radius, child: content),
    );
  }
}

/// 무대 위 유리 원 버튼(지름 36, 흰 아이콘).
class StageCircleButton extends StatelessWidget {
  const StageCircleButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  static const double size = 36;

  @override
  Widget build(BuildContext context) {
    const radius = BorderRadius.all(Radius.circular(size / 2));
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: tooltip,
        excludeSemantics: true,
        child: SizedBox.square(
          dimension: size,
          child: StageGlass(
            borderRadius: radius,
            child: InkWell(
              onTap: onPressed,
              borderRadius: radius,
              child: Center(child: Icon(icon, size: 20, color: Colors.white)),
            ),
          ),
        ),
      ),
    );
  }
}

/// 탭 화면 맨 위 파란 무대: 큰 제목 · 설명 · [trailing] 원 버튼 · [children].
/// 안전 영역 위 여백까지 무대가 채우므로 화면 맨 위에 붙여서 쓴다.
class PageStage extends StatelessWidget {
  const PageStage.tab({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.children = const [],
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top + 14;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: StageBackground(
        child: Padding(
          padding: EdgeInsets.fromLTRB(18, top, 18, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: StageText.title,
                        ),
                        if (subtitle != null && subtitle!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            subtitle!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: StageText.subtitle,
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (trailing != null) ...[
                    const SizedBox(width: 12),
                    trailing!,
                  ],
                ],
              ),
              for (var i = 0; i < children.length; i++) ...[
                SizedBox(height: i == 0 ? 16 : 12),
                children[i],
              ],
            ],
          ),
        ),
      ),
    );
  }
}
