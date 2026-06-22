/// 웹 KaTeX(`MathMixedRich`)와 동일: `$…$`, `$$…$$`, `\( … \)`, `\[ … \]`
enum MathMixedSegmentKind { plain, inlineMath, displayMath }

class MathMixedSegment {
  const MathMixedSegment(this.kind, this.value);

  final MathMixedSegmentKind kind;
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

List<MathMixedSegment> parseMathMixed(String source) {
  if (source.isEmpty) {
    return const [MathMixedSegment(MathMixedSegmentKind.plain, '')];
  }
  final out = <MathMixedSegment>[];
  var pos = 0;

  while (pos < source.length) {
    final next = _pickNextDelimiter(source, pos);
    if (next == null) {
      out.add(MathMixedSegment(MathMixedSegmentKind.plain, source.substring(pos)));
      break;
    }

    if (next.start > pos) {
      out.add(MathMixedSegment(MathMixedSegmentKind.plain, source.substring(pos, next.start)));
    }

    switch (next.kind) {
      case _Delim.dd:
        final open = next.start + 2;
        final close = _indexOfDoubleDollar(source, open);
        if (close < 0) {
          out.add(MathMixedSegment(MathMixedSegmentKind.plain, source.substring(next.start)));
          pos = source.length;
          break;
        }
        out.add(
          MathMixedSegment(
            MathMixedSegmentKind.displayMath,
            source.substring(open, close).trim(),
          ),
        );
        pos = close + 2;
        break;
      case _Delim.sd:
        final open = next.start + 1;
        final close = _closingSingleDollar(source, open);
        if (close < 0) {
          out.add(MathMixedSegment(MathMixedSegmentKind.plain, source.substring(next.start)));
          pos = source.length;
          break;
        }
        out.add(
          MathMixedSegment(
            MathMixedSegmentKind.inlineMath,
            source.substring(open, close).trim(),
          ),
        );
        pos = close + 1;
        break;
      case _Delim.bracket:
        final open = next.start + 2;
        final close = source.indexOf(r'\]', open);
        if (close < 0) {
          out.add(MathMixedSegment(MathMixedSegmentKind.plain, source.substring(next.start)));
          pos = source.length;
          break;
        }
        out.add(
          MathMixedSegment(
            MathMixedSegmentKind.displayMath,
            source.substring(open, close).trim(),
          ),
        );
        pos = close + 2;
        break;
      case _Delim.paren:
        final open = next.start + 2;
        final close = source.indexOf(r'\)', open);
        if (close < 0) {
          out.add(MathMixedSegment(MathMixedSegmentKind.plain, source.substring(next.start)));
          pos = source.length;
          break;
        }
        out.add(
          MathMixedSegment(
            MathMixedSegmentKind.inlineMath,
            source.substring(open, close).trim(),
          ),
        );
        pos = close + 2;
        break;
    }
  }

  return out.isEmpty ? [MathMixedSegment(MathMixedSegmentKind.plain, source)] : out;
}

String compactMathMixedLineBreaks(String input) {
  var s = input.replaceAll('\r\n', '\n');
  s = s.replaceAll(RegExp(r'\n{2,}'), '\n');
  return s
      .split('\n')
      .map((line) => line.trimRight())
      .join('\n')
      .trim();
}
