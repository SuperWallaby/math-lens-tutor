import 'package:flutter/material.dart';

import '../theme/app_design_system.dart';

/// iPad 등 넓은 화면에서 본문 폭·패딩·타이포를 키워 스토어 스크린샷에 맞게 보이도록 한다.
abstract final class TabletLayout {
  TabletLayout._();

  static bool isTablet(BuildContext context) {
    return MediaQuery.sizeOf(context).shortestSide >= 600;
  }

  static bool isWideTablet(BuildContext context) {
    return MediaQuery.sizeOf(context).width >= 900;
  }

  /// 태블릿에서는 화면 너비의 대부분을 쓰고, 아주 넓은 창에서는 상한만 둔다.
  static double maxContentWidth(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    if (!isTablet(context)) {
      return w;
    }
    return (w * 0.94).clamp(720.0, 1400.0);
  }

  /// Page insets. Top includes status-bar safe area when the body is full-bleed
  /// (e.g. bottom-nav tabs). Inside [SafeArea] / below [AppBar], adds content-only top air.
  static EdgeInsets pagePadding(BuildContext context) {
    final safeTop = MediaQuery.paddingOf(context).top;
    final top = safeTop > 0 ? safeTop + AppSpacing.lg : AppSpacing.xxl;

    if (isWideTablet(context)) {
      return EdgeInsets.fromLTRB(40, top + AppSpacing.sm, 40, 28);
    }
    if (isTablet(context)) {
      return EdgeInsets.fromLTRB(32, top + AppSpacing.xs, 32, 24);
    }
    return EdgeInsets.fromLTRB(24, top, 24, 24);
  }

  /// [AppBar] 아래 본문 — status bar 중복 패딩 없이 좌우만 [pagePadding] 과 맞춤.
  static EdgeInsets appBarBodyPadding(BuildContext context) {
    if (isWideTablet(context)) {
      return const EdgeInsets.fromLTRB(40, AppSpacing.md, 40, 28);
    }
    if (isTablet(context)) {
      return const EdgeInsets.fromLTRB(32, AppSpacing.md, 32, 24);
    }
    return const EdgeInsets.fromLTRB(24, AppSpacing.md, 24, 24);
  }

  static double pageHorizontalPadding(BuildContext context) {
    if (isWideTablet(context)) return 40;
    if (isTablet(context)) return 32;
    return 24;
  }

  static double titleHero(BuildContext context) =>
      isWideTablet(context) ? 46 : 34;

  static double titleSection(BuildContext context) =>
      isWideTablet(context) ? 30 : 26;

  static double body(BuildContext context) =>
      isWideTablet(context) ? 19 : 16;

  static double bodySmall(BuildContext context) =>
      isWideTablet(context) ? 17 : 14;
}

/// 본문을 가운데 정렬하고 태블릿에서 최대 폭을 넓힌다.
class TabletBody extends StatelessWidget {
  const TabletBody({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: TabletLayout.maxContentWidth(context),
        ),
        child: child,
      ),
    );
  }
}
