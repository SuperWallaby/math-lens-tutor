import 'package:flutter/material.dart';

import 'mixed_math_text.dart';

/// 목록 한 줄~두 줄 미리보기 — 글자 `…` 대신 레이아웃 클립 (수식 파서 깨짐 방지)
class MixedMathListTitle extends StatelessWidget {
  const MixedMathListTitle(
    this.text, {
    super.key,
    required this.style,
    this.maxLines = 2,
  });

  final String text;
  final TextStyle style;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final lineHeight = style.height ?? 1.35;
    final fontSize = style.fontSize ?? 15;
    final maxHeight = fontSize * lineHeight * maxLines + 1;

    return ClipRect(
      child: Align(
        alignment: Alignment.topLeft,
        heightFactor: 1,
        child: SizedBox(
          height: maxHeight,
          child: MixedMathText(
            text,
            style: style,
            paragraphSoftBreak: true,
          ),
        ),
      ),
    );
  }
}
