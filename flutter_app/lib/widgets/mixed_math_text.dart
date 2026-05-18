import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';

import '../utils/format_readable_solution_text.dart';
import '../utils/soft_break_korean_math_text.dart';

/// 웹 KaTeX(`MathMixedRich`)와 동일: `$…$`, `$$…$$`, `\( … \)`, `\[ … \]`
enum _SegKind { plain, inlineMath, displayMath }

class _Seg {
  const _Seg(this.kind, this.value);
  final _SegKind kind;
  final String value;
}

int _indexOfDoubleDollar(String s, int from) => s.indexOf(r'$$', from);

int _indexOfSingleDollar(String s, int from) {
  var i = s.indexOf(r'$', from);
  while (i >= 0) {
    if (i + 1 >= s.length || s[i + 1] != r'$') return i;
    i = s.indexOf(r'$', i + 2);
  }
  return -1;
}

int _closingSingleDollar(String s, int from) {
  var i = s.indexOf(r'$', from);
  while (i >= 0) {
    if (i + 1 >= s.length || s[i + 1] != r'$') return i;
    i = s.indexOf(r'$', i + 2);
  }
  return -1;
}

enum _Delim { dd, sd, bracket, paren }

({int start, _Delim kind})? _pickNextDelimiter(String s, int pos) {
  final candidates = <({int start, _Delim kind})>[];

  final iDd = _indexOfDoubleDollar(s, pos);
  if (iDd >= 0) candidates.add((start: iDd, kind: _Delim.dd));

  final iSd = _indexOfSingleDollar(s, pos);
  if (iSd >= 0) candidates.add((start: iSd, kind: _Delim.sd));

  final iBr = s.indexOf(r'\[', pos);
  if (iBr >= 0) candidates.add((start: iBr, kind: _Delim.bracket));

  final iPa = s.indexOf(r'\(', pos);
  if (iPa >= 0) candidates.add((start: iPa, kind: _Delim.paren));

  if (candidates.isEmpty) return null;

  final minStart = candidates.map((c) => c.start).reduce((a, b) => a < b ? a : b);
  final ties = candidates.where((c) => c.start == minStart).toList();
  const prio = [_Delim.dd, _Delim.bracket, _Delim.paren, _Delim.sd];
  for (final p in prio) {
    for (final t in ties) {
      if (t.kind == p) return t;
    }
  }
  return ties.first;
}

List<_Seg> _parseMathMixed(String source) {
  if (source.isEmpty) {
    return const [_Seg(_SegKind.plain, '')];
  }
  final out = <_Seg>[];
  var pos = 0;

  while (pos < source.length) {
    final next = _pickNextDelimiter(source, pos);
    if (next == null) {
      out.add(_Seg(_SegKind.plain, source.substring(pos)));
      break;
    }

    if (next.start > pos) {
      out.add(_Seg(_SegKind.plain, source.substring(pos, next.start)));
    }

    switch (next.kind) {
      case _Delim.dd:
        final open = next.start + 2;
        final close = _indexOfDoubleDollar(source, open);
        if (close < 0) {
          out.add(_Seg(_SegKind.plain, source.substring(next.start)));
          pos = source.length;
          break;
        }
        out.add(
          _Seg(
            _SegKind.displayMath,
            source.substring(open, close).trim(),
          ),
        );
        pos = close + 2;
        break;
      case _Delim.sd:
        final open = next.start + 1;
        final close = _closingSingleDollar(source, open);
        if (close < 0) {
          out.add(_Seg(_SegKind.plain, source.substring(next.start)));
          pos = source.length;
          break;
        }
        out.add(
          _Seg(
            _SegKind.inlineMath,
            source.substring(open, close).trim(),
          ),
        );
        pos = close + 1;
        break;
      case _Delim.bracket:
        final open = next.start + 2;
        final close = source.indexOf(r'\]', open);
        if (close < 0) {
          out.add(_Seg(_SegKind.plain, source.substring(next.start)));
          pos = source.length;
          break;
        }
        out.add(
          _Seg(
            _SegKind.displayMath,
            source.substring(open, close).trim(),
          ),
        );
        pos = close + 2;
        break;
      case _Delim.paren:
        final open = next.start + 2;
        final close = source.indexOf(r'\)', open);
        if (close < 0) {
          out.add(_Seg(_SegKind.plain, source.substring(next.start)));
          pos = source.length;
          break;
        }
        out.add(
          _Seg(
            _SegKind.inlineMath,
            source.substring(open, close).trim(),
          ),
        );
        pos = close + 2;
        break;
    }
  }

  return out.isEmpty ? [_Seg(_SegKind.plain, source)] : out;
}

void _appendPlainSpans(List<InlineSpan> buffer, String plain) {
  if (plain.isEmpty) {
    return;
  }
  final parts = plain.split('\n');
  for (var i = 0; i < parts.length; i++) {
    buffer.add(TextSpan(text: parts[i]));
    if (i < parts.length - 1) {
      buffer.add(const TextSpan(text: '\n'));
    }
  }
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
  });

  final String text;
  final TextStyle style;
  final TextAlign textAlign;
  final bool paragraphSoftBreak;
  final bool readableSolutionStep;

  @override
  Widget build(BuildContext context) {
    final normalized = text.replaceAll('\r\n', '\n');
    final source = readableSolutionStep
        ? formatReadableSolutionText(normalized)
        : paragraphSoftBreak
            ? softBreakAnswerExplanation(normalized)
            : normalized;
    final segs = _parseMathMixed(source);
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
        case _SegKind.plain:
          _appendPlainSpans(buffer, seg.value);
          break;
        case _SegKind.inlineMath:
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
        case _SegKind.displayMath:
          flushRich();
          children.add(
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
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
