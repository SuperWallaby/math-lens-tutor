/// 웹 `augment-math-delimiters.ts` 와 동일 — `$` 없이 섞인 LaTeX를 KaTeX/Math.tex 가 읽을 수 있게 감쌉니다.
int _consumeBalancedBrace(String s, int openBrace) {
  var depth = 1;
  var k = openBrace + 1;
  while (k < s.length && depth > 0) {
    final ch = s[k];
    if (ch == '{') {
      depth++;
    } else if (ch == '}') {
      depth--;
    }
    k++;
  }
  return k;
}

int _skipSpaces(String s, int from) {
  var k = from;
  while (k < s.length && RegExp(r'\s').hasMatch(s[k])) {
    k++;
  }
  return k;
}

({String full, int end})? _tryParseFracAt(String s, int i) {
  if (!s.startsWith(r'\frac', i)) return null;
  var pos = _skipSpaces(s, i + 5);
  if (pos >= s.length || s[pos] != '{') return null;
  pos = _consumeBalancedBrace(s, pos);
  pos = _skipSpaces(s, pos);
  if (pos >= s.length || s[pos] != '{') return null;
  pos = _consumeBalancedBrace(s, pos);
  return (full: s.substring(i, pos), end: pos);
}

({String full, int end})? _tryParseSqrtAt(String s, int i) {
  if (!s.startsWith(r'\sqrt', i)) return null;
  var pos = _skipSpaces(s, i + 5);
  if (pos < s.length && s[pos] == '[') {
    final close = s.indexOf(']', pos + 1);
    if (close < 0) return null;
    pos = _skipSpaces(s, close + 1);
  }
  if (pos >= s.length || s[pos] != '{') return null;
  pos = _consumeBalancedBrace(s, pos);
  return (full: s.substring(i, pos), end: pos);
}

String _wrapNestedConstructs(String s) {
  final stack = <String>[];
  var pos = 0;
  while (pos < s.length) {
    if (s.startsWith(r'\sqrt', pos)) {
      final parsed = _tryParseSqrtAt(s, pos);
      if (parsed != null) {
        stack.add(parsed.full);
        pos = parsed.end;
        continue;
      }
    }
    if (s.startsWith(r'\frac', pos)) {
      final parsed = _tryParseFracAt(s, pos);
      if (parsed != null) {
        stack.add(parsed.full);
        pos = parsed.end;
        continue;
      }
    }
    pos++;
  }

  var t = s;
  final unique = stack.toSet().toList()
    ..sort((a, b) => b.length.compareTo(a.length));
  for (final fragment in unique) {
    if (fragment.contains(r'$')) continue;
    t = t.split(fragment).join('\$$fragment\$');
  }
  return t;
}

int _consumeBareLatexRun(String s, int start) {
  var j = start;
  while (j < s.length) {
    if (s[j] == r'\' && j + 1 < s.length && RegExp(r'[a-zA-Z]').hasMatch(s[j + 1])) {
      j++;
      while (j < s.length && RegExp(r'[a-zA-Z]').hasMatch(s[j])) {
        j++;
      }
      if (j < s.length && s[j] == '*') j++;
      continue;
    }
    if (RegExp(r'\s').hasMatch(s[j])) {
      final spStart = j;
      var sp = j;
      while (sp < s.length && RegExp(r'\s').hasMatch(s[sp])) {
        sp++;
      }
      if (sp - spStart >= 2) break;
      if (sp < s.length && s[sp] == r'\') {
        j = sp;
        continue;
      }
      break;
    }
    final ch = s[j];
    if (RegExp(r'[가-힣ㄱ-ㅎㅏ-ㅣ]').hasMatch(ch)) break;
    if (RegExp(r'[0-9.]').hasMatch(ch)) {
      while (j < s.length && RegExp(r'[0-9.]').hasMatch(s[j])) {
        j++;
      }
      continue;
    }
    if (RegExp(r'''[+\-=*/<>≠≤≥.(),;:!'|≈]''').hasMatch(ch)) {
      j++;
      continue;
    }
    if (RegExp(r'[A-Za-z]').hasMatch(ch)) {
      while (j < s.length && RegExp(r'[A-Za-z]').hasMatch(s[j])) {
        j++;
      }
      continue;
    }
    if (ch == '_' || ch == '^') {
      j++;
      if (j < s.length && s[j] == '{') {
        j = _consumeBalancedBrace(s, j);
        continue;
      }
      if (j < s.length && RegExp(r'[0-9A-Za-z(]').hasMatch(s[j])) {
        j++;
      }
      continue;
    }
    if (ch == '{') {
      j = _consumeBalancedBrace(s, j);
      continue;
    }
    break;
  }
  return j;
}

String _wrapBackslashSequencesOutsideDelimiters(String fragment) {
  if (!fragment.contains(r'\')) return fragment;
  final buffer = StringBuffer();
  var i = 0;
  while (i < fragment.length) {
    if (fragment[i] == r'\' &&
        i + 1 < fragment.length &&
        RegExp(r'[a-zA-Z]').hasMatch(fragment[i + 1])) {
      final end = _consumeBareLatexRun(fragment, i);
      if (end > i) {
        final piece = fragment.substring(i, end).trimRight();
        if (piece.isNotEmpty && piece.contains(r'\')) {
          buffer.write('\$$piece\$');
          i = end;
          continue;
        }
      }
    }
    buffer.write(fragment[i]);
    i++;
  }
  return buffer.toString();
}

String _transformOutsideExistingMath(String s, String Function(String) fn) {
  if (!s.contains(r'$')) return fn(s);
  final chunks = s.split(r'$');
  final out = StringBuffer();
  for (var idx = 0; idx < chunks.length; idx++) {
    out.write(idx.isEven ? fn(chunks[idx]) : chunks[idx]);
    if (idx < chunks.length - 1) out.write(r'$');
  }
  return out.toString();
}

bool _segmentHasBareLatex(String s) {
  if (s.trim().isEmpty) return false;
  return RegExp(r'\^[0-9]|_[0-9a-z]|\)\^|[²³⁴]').hasMatch(s) ||
      RegExp(r'\\(?:[a-zA-Z]+\*?)', caseSensitive: false).hasMatch(s);
}

String _augmentPlainConstructs(String input) {
  var t = input;
  t = t.replaceAllMapped(RegExp(r'\([^()]*\)\^[0-9]+'), (m) => '\$${m[0]}\$');
  t = t.replaceAllMapped(
    RegExp(r'\b([a-zA-Z])\s*=\s*([a-zA-Z0-9+*/().\s-]+)'),
    (m) {
      final rhs = m.group(2)!.trim();
      if (!RegExp(r'[\^_]|\\|\\frac|\\sqrt').hasMatch(rhs)) {
        return m[0]!;
      }
      return '\$${m.group(1)}=$rhs\$';
    },
  );
  t = t.replaceAllMapped(RegExp(r'\b[a-zA-Z][a-zA-Z0-9\x27]*\^[0-9]+\b'), (m) {
    if (m[0]!.contains(r'$')) return m[0]!;
    return '\$${m[0]}\$';
  });
  t = t.replaceAllMapped(
    RegExp(r'\b[a-zA-Z][a-zA-Z0-9\x27]*_[0-9a-z]+\b', caseSensitive: false),
    (m) {
      if (m[0]!.contains(r'$')) return m[0]!;
      return '\$${m[0]}\$';
    },
  );
  t = t.replaceAllMapped(RegExp(r'([a-zA-Z])[²³⁴]'), (m) {
    const map = {'²': '^2', '³': '^3', '⁴': '^4'};
    final sup = m[0]!.substring(m[0]!.length - 1);
    return '\$${m.group(1)}${map[sup] ?? '^2'}\$';
  });
  t = t.replaceAllMapped(RegExp(r'\([^()]+\)[²³⁴]'), (m) {
    const map = {'²': '^2', '³': '^3', '⁴': '^4'};
    final sup = m[0]!.substring(m[0]!.length - 1);
    final base = m[0]!.substring(0, m[0]!.length - 1);
    return '\$${base}${map[sup] ?? '^2'}\$';
  });
  t = t.replaceAllMapped(
    RegExp(r'[\d.]+\s*\\(?:times|cdot)\s*[\d.]+', caseSensitive: false),
    (m) => '\$${m[0]}\$',
  );
  return t;
}

String augmentMathDelimiters(String input) {
  final s = input;
  if (s.trim().isEmpty) return s;

  final hasDelimiter = RegExp(r'\$|\\\(|\\\[').hasMatch(s);
  if (hasDelimiter) return s;

  if (!_segmentHasBareLatex(s)) return s;

  var t = _transformOutsideExistingMath(s, _augmentPlainConstructs);
  t = _transformOutsideExistingMath(t, _wrapNestedConstructs);
  t = _transformOutsideExistingMath(t, _wrapBackslashSequencesOutsideDelimiters);
  return t;
}
