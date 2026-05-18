import 'soft_break_korean_math_text.dart';

/// 한글·수식·문장부호가 붙은 LLM 풀이 문자열 정리 (웹 `format-readable-solution-text.ts` 와 동일 목적)
String insertHangulMathSpacing(String input) {
  var s = input;
  s = s.replaceAllMapped(RegExp(r'([가-힣])(\$)'), (m) => '${m[1]} ${m[2]}');
  s = s.replaceAllMapped(
    RegExp(r'(\$[^$\n]*\$)([가-힣])'),
    (m) => '${m[1]} ${m[2]}',
  );
  s = s.replaceAllMapped(RegExp(r'([가-힣])(\\[a-zA-Z])'), (m) => '${m[1]} ${m[2]}');
  s = s.replaceAllMapped(
    RegExp(r'(\\(?:frac|sqrt|left|right|cdot|times|le|ge|ne|pm)[^가-힣]*?)([가-힣])'),
    (m) => '${m[1]} ${m[2]}',
  );
  s = s.replaceAllMapped(RegExp(r'([.!?,:;])([가-힣])'), (m) => '${m[1]} ${m[2]}');
  s = s.replaceAllMapped(RegExp(r'([)\]}>"\x27])([가-힣])'), (m) => '${m[1]} ${m[2]}');
  return s.replaceAll(RegExp(r' {2,}'), ' ');
}

String softBreakSolutionStepText(String input) {
  var s = input.replaceAll('\r\n', '\n');
  if (s.trim().isEmpty || s.contains('\n')) {
    return insertHangulMathSpacing(s);
  }

  var t = softBreakAnswerExplanation(s);
  if (t.contains('\n')) {
    return insertHangulMathSpacing(t);
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
    t = parts.where((p) => p.isNotEmpty).join('\n\n');
  }

  return insertHangulMathSpacing(t);
}

String formatReadableSolutionText(String input) =>
    softBreakSolutionStepText(input);
