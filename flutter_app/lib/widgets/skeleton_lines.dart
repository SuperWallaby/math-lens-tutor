import 'package:flutter/material.dart';

import 'skeleton_box.dart';

/// 텍스트 라인 형태 스켈레톤 (너비는 부모 대비 비율 0~1).
class SkeletonLines extends StatelessWidget {
  const SkeletonLines({
    super.key,
    required this.widthFactors,
    this.tint = SkeletonTint.neutral,
    this.lineHeight = 14,
    this.gap = 8,
  });

  final List<double> widthFactors;
  final SkeletonTint tint;
  final double lineHeight;
  final double gap;

  /// 정답 풀이
  static const answerSolution = [0.92, 0.68, 0.84];

  /// 풀이과정·불릿
  static const studentSteps = [0.52, 0.84, 0.68, 0.92, 0.56];

  /// 일반 문단
  static const paragraph = [0.92, 0.68, 0.84, 0.52];

  /// 짧은 답안
  static const short = [0.72, 0.48];

  /// 오답 진단
  static const error = [0.88, 0.62];

  /// 부족 개념·훈련
  static const training = [0.42, 0.88, 0.68];

  /// CTA
  static const button = [0.88];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = constraints.maxWidth;
        if (!maxW.isFinite || maxW <= 0) {
          return const SizedBox.shrink();
        }
        final children = <Widget>[];
        for (var i = 0; i < widthFactors.length; i++) {
          if (i > 0) children.add(SizedBox(height: gap));
          final w = (maxW * widthFactors[i].clamp(0.12, 1.0)).clamp(48.0, maxW);
          children.add(
            SkeletonBox(
              width: w,
              height: lineHeight,
              borderRadius: 999,
              tint: tint,
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        );
      },
    );
  }
}
