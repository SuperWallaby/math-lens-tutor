import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';

import '../utils/augment_math_delimiters.dart';
import '../utils/format_readable_solution_text.dart';
import '../utils/math_mixed_segments.dart';
import '../utils/soft_break_korean_math_text.dart';

void _appendPlainSpans(
  List<InlineSpan> buffer,
  String plain, {
  bool preserveWhitespace = false,
}) {
  if (plain.isEmpty) {
    return;
  }

  final lines = plain.split('\n').where((line) => line.isNotEmpty).toList();
  for (var i = 0; i < lines.length; i++) {
    buffer.add(
      TextSpan(
        text: preserveWhitespace ? _preserveLineSpaces(lines[i]) : lines[i],
      ),
    );
    if (i < lines.length - 1) {
      buffer.add(const TextSpan(text: '\n'));
    }
  }
}

/// CSS `white-space: pre-wrap` — 연속 공백 보존 (줄바꿈은 `\n` 유지)
String _preserveLineSpaces(String line) {
  return line.replaceAllMapped(
    RegExp(r' {2,}'),
    (m) => '\u00a0' * m.group(0)!.length,
  );
}

/// 한국어 본문 + LaTeX 혼합 (선택된 화면용)
class MixedMathText extends StatelessWidget {
  const MixedMathText(
    this.text, {
    super.key,
    required this.style,
    this.textAlign = TextAlign.start,
    /// 웹 추정 정답과 같이 긴 안내 문자열 단락 구분 보강
    this.paragraphSoftBreak = false,
    /// 정답 풀이·학생 풀이 단계 — 한글·수식 띄어쓰기·단락
    this.readableSolutionStep = false,
    /// 웹 `whitespace-pre-wrap` — 줄바꿈·연속 공백 보존
    this.preserveWhitespace = false,
  });

  final String text;
  final TextStyle style;
  final TextAlign textAlign;
  final bool paragraphSoftBreak;
  final bool readableSolutionStep;
  final bool preserveWhitespace;

  @override
  Widget build(BuildContext context) {
    final normalized = augmentMathDelimiters(compactMathMixedLineBreaks(text));
    final source = preserveWhitespace
        ? (normalized.contains('\n')
            ? normalized
            : softBreakAnswerExplanation(normalized))
        : readableSolutionStep
            ? formatReadableSolutionText(normalized)
            : paragraphSoftBreak
                ? softBreakAnswerExplanation(normalized)
                : normalized;
    final segs = parseMathMixed(source);
    final children = <Widget>[];
    var buffer = <InlineSpan>[];

    void flushRich() {
      if (buffer.isEmpty) return;
      children.add(
        RichText(
          textAlign: textAlign,
          text: TextSpan(style: style, children: [...buffer]),
        ),
      );
      buffer = [];
    }

    Widget mathFallback(FlutterMathException err, String latex) => Text(
          latex,
          style: style.merge(const TextStyle(fontFamily: 'monospace')),
        );

    for (final seg in segs) {
      switch (seg.kind) {
        case MathMixedSegmentKind.plain:
          _appendPlainSpans(
            buffer,
            seg.value,
            preserveWhitespace: preserveWhitespace,
          );
          break;
        case MathMixedSegmentKind.inlineMath:
          buffer.add(
            WidgetSpan(
              alignment: PlaceholderAlignment.baseline,
              baseline: TextBaseline.alphabetic,
              child: Math.tex(
                seg.value,
                mathStyle: MathStyle.text,
                textStyle: style,
                onErrorFallback: (e) => mathFallback(e, seg.value),
              ),
            ),
          );
          break;
        case MathMixedSegmentKind.displayMath:
          flushRich();
          children.add(
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Math.tex(
                  seg.value,
                  mathStyle: MathStyle.display,
                  textStyle: style,
                  onErrorFallback: (e) => mathFallback(e, seg.value),
                ),
              ),
            ),
          );
          break;
      }
    }
    flushRich();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }
}
