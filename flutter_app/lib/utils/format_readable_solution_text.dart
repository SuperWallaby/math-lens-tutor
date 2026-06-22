import 'soft_break_korean_math_text.dart';

/// 한글·수식·문장부호가 붙은 LLM 풀이 문자열 정리 (웹 `format-readable-solution-text.ts` 와 동일 목적)
String insertHangulMathSpacing(String input) {
  var s = input;
  s = s.replaceAllMapped(RegExp(r'([가-힣])(\$)'), (m) => '${m[1]} ${m[2]}');
  s = s.replaceAllMapped(
    RegExp(r'(\$[^$\n]*\$)([가-힣])'),
    (m) => '${m[1]} ${m[2]}',
  );
  s = s.replaceAllMapped(
    RegExp(r'([가-힣])(\\[a-zA-Z])'),
    (m) => '${m[1]} ${m[2]}',
  );
  s = s.replaceAllMapped(
    RegExp(
      r'(\\(?:frac|sqrt|left|right|cdot|times|le|ge|ne|pm)[^가-힣]*?)([가-힣])',
    ),
    (m) => '${m[1]} ${m[2]}',
  );
  s = s.replaceAllMapped(
    RegExp(r'([.!?,:;])([가-힣])'),
    (m) => '${m[1]} ${m[2]}',
  );
  s = s.replaceAllMapped(
    RegExp(r'([)\]}>"\x27])([가-힣])'),
    (m) => '${m[1]} ${m[2]}',
  );
  return s.replaceAll(RegExp(r' {2,}'), ' ');
}

List<String> _splitByMathTokens(String input) {
  final parts = <String>[];
  final re = RegExp(r'(\$\$[\s\S]*?\$\$|\$[^$\n]*\$)');
  var last = 0;
  for (final match in re.allMatches(input)) {
    if (match.start > last) {
      parts.add(input.substring(last, match.start));
    }
    parts.add(input.substring(match.start, match.end));
    last = match.end;
  }
  if (last < input.length) {
    parts.add(input.substring(last));
  }
  return parts;
}

String _softBreakLongPlainText(String input, {int threshold = 46}) {
  var text = input;
  final chunks = <String>[];
  final boundary = RegExp(r'(?:[.!?。]|다\.|요\.|니다\.|한다\.|된다\.)\s+');
  var last = 0;
  for (final match in boundary.allMatches(text)) {
    chunks.add(text.substring(last, match.end).trim());
    last = match.end;
  }
  if (last < text.length) {
    chunks.add(text.substring(last).trim());
  }
  if (chunks.length > 1) {
    final lines = <String>[];
    var current = '';
    for (final chunk
        in chunks.map((e) => e.trim()).where((e) => e.isNotEmpty)) {
      if (current.isEmpty) {
        current = chunk;
      } else if ('$current $chunk'.length <= threshold) {
        current = '$current $chunk';
      } else {
        lines.add(current);
        current = chunk;
      }
    }
    if (current.isNotEmpty) lines.add(current);
    text = lines.join('\n');
  }

  text = text.replaceAllMapped(
    RegExp(r'\s+(?=따라서|그러므로|그래서|또한|다음으로|마지막으로|이때|이므로|정리하면|결과적으로|즉,)'),
    (_) => '\n',
  );

  return text;
}

String _softBreakLongSolutionText(String input) {
  final parts = _splitByMathTokens(input);
  final out = StringBuffer();
  for (final part in parts) {
    final isMath = part.startsWith(r'$');
    out.write(isMath ? part : _softBreakLongPlainText(part));
  }
  return out
      .toString()
      .replaceAll(RegExp(r'\n{3,}'), '\n\n')
      .replaceAll(RegExp(r' *\n *'), '\n');
}

String softBreakSolutionStepText(String input) {
  var s = input.replaceAll('\r\n', '\n');
  if (s.trim().isEmpty || s.contains('\n')) {
    return insertHangulMathSpacing(_softBreakLongSolutionText(s));
  }

  var t = softBreakAnswerExplanation(s);
  if (t.contains('\n')) {
    return insertHangulMathSpacing(_softBreakLongSolutionText(t));
  }

  final expl = RegExp(
    r'\s+(?=따라서|그러므로|그래서|또한|때문에|이때|이므로|정리하면|결과적으로|단계\s*\d|제\d|첫째|둘째|셋째|마지막으로|즉,)',
  );
  final parts = <String>[];
  var last = 0;
  for (final m in expl.allMatches(t)) {
    if (m.start > last) {
      parts.add(t.substring(last, m.start).trimRight());
    }
    last = m.end;
  }
  if (last < t.length) {
    parts.add(t.substring(last).trimLeft());
  }
  if (parts.length > 1) {
    t = parts.where((p) => p.isNotEmpty).join('\n');
  }

  return insertHangulMathSpacing(_softBreakLongSolutionText(t));
}

String formatReadableSolutionText(String input) =>
    softBreakSolutionStepText(input);
