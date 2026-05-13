/// 웹 `src/lib/soft-break-korean-math-text.ts` 와 동일 규칙
String softBreakAnswerExplanation(String input) {
  var s = input.replaceAll('\r\n', '\n');
  if (s.trim().isEmpty) return s;
  if (s.contains('\n')) return s;

  final expl = RegExp(
    r'\s+(?=코사인|사인\s*법칙|법칙을\s*이용|따라서|그러므로|먼저|여기(?:서|부터)|이를\s*이용|식(?:으로|을)\s*|두\s*삼각형|넓이|반지름|각도\s*를|평균|삼각(?:형|함수))',
  );
  final m = expl.firstMatch(s);
  if (m == null) return s;

  final head = s.substring(0, m.start).trimRight();
  final tail = s.substring(m.start).trimLeft();
  return '$head\n\n$tail';
}
