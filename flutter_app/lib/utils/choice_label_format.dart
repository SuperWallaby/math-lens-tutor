/// 선지 label 앞의 "1. ", "1) ", "(1) ", "①" 등 중복 번호 제거
String stripLeadingChoiceMarker(String label, [String? choiceId]) {
  var text = label.trim();
  if (text.isEmpty) return text;

  const circles = ['①', '②', '③', '④', '⑤', '⑥', '⑦', '⑧', '⑨', '⑩'];
  final id = choiceId?.trim();
  if (id != null && id.isNotEmpty) {
    final num = int.tryParse(id);
    if (num != null && num >= 1 && num <= circles.length) {
      final circle = circles[num - 1];
      if (text.startsWith(circle)) {
        text = text.substring(circle.length).trim();
      }
    }

    final patterns = [
      RegExp('^\\(?${RegExp.escape(id)}\\)?\\.\\s+'),
      RegExp('^\\(?${RegExp.escape(id)}\\)?\\)\\s+'),
      RegExp('^${RegExp.escape(id)}:\\s+'),
      RegExp('^${RegExp.escape(id)}\\s+(?!\\d)'),
    ];
    for (final pattern in patterns) {
      if (pattern.hasMatch(text)) {
        text = text.replaceFirst(pattern, '').trim();
        break;
      }
    }
  }

  text = text.replaceFirst(RegExp(r'^[①②③④⑤⑥⑦⑧⑨⑩]\s*'), '');
  text = text.replaceFirst(RegExp(r'^\(?[1-9]\)?[.):：、]\s+'), '');
  return text;
}

/// UI 표시용 — label만 쓰고 id 인덱스(1. 2. …)는 붙이지 않음
String formatChoiceDisplayLabel(String id, String label) {
  return stripLeadingChoiceMarker(label, id);
}
