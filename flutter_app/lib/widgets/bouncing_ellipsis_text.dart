import 'dart:math' as math;

import 'package:flutter/material.dart';

/// "문제 만드는 중" + 통통 튀는 `...` (개수 변화 `.` → `..` → `...` 아님)
class BouncingEllipsisText extends StatelessWidget {
  const BouncingEllipsisText({
    super.key,
    required this.text,
    required this.controller,
    required this.style,
    this.textAlign = TextAlign.center,
    this.dotLift = 4,
    this.dotSpacing = 1,
  });

  final String text;
  final AnimationController controller;
  final TextStyle style;
  final TextAlign textAlign;
  final double dotLift;
  final double dotSpacing;

  @override
  Widget build(BuildContext context) {
    final trimmed = text.replaceAll(RegExp(r'[.…]+$'), '').trimRight();

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final dots = Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            final phase = (controller.value + index / 3) % 1.0;
            final wave = phase < 0.5 ? phase * 2 : (1 - phase) * 2;
            return Padding(
              padding: EdgeInsets.only(left: index == 0 ? 0 : dotSpacing),
              child: Transform.translate(
                offset: Offset(0, -dotLift * wave),
                child: Opacity(
                  opacity: 0.35 + (0.65 * wave),
                  child: Text('.', style: style),
                ),
              ),
            );
          }),
        );

        if (textAlign == TextAlign.center) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(trimmed, textAlign: TextAlign.center, style: style),
              dots,
            ],
          );
        }

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(trimmed, style: style),
            dots,
          ],
        );
      },
    );
  }
}

/// Row 안에서 쓰는 인라인 버전 (예: `채점 중` + ...)
class BouncingEllipsisInline extends StatelessWidget {
  const BouncingEllipsisInline({
    super.key,
    required this.prefix,
    required this.controller,
    required this.style,
    this.dotLift = 4,
  });

  final String prefix;
  final AnimationController controller;
  final TextStyle style;
  final double dotLift;

  @override
  Widget build(BuildContext context) {
    return BouncingEllipsisText(
      text: prefix,
      controller: controller,
      style: style,
      textAlign: TextAlign.start,
      dotLift: dotLift,
    );
  }
}

/// 부드러운 사인파 bounce — 필요 시 대안
double bouncingDotWave(double controllerValue, int index) {
  final phase = (controllerValue + index / 3) % 1.0;
  return math.max(0, math.sin(phase * math.pi));
}
