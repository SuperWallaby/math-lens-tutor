import '../models/app_models.dart';

/// AI가 지정하거나 클라이언트가 추론하는 답안 입력 형식.
enum ProblemAnswerFormat {
  multipleChoice,
  shortNumeric,
  shortAnswer;

  static ProblemAnswerFormat? fromApiValue(String? raw) {
    switch (raw?.trim()) {
      case 'short_numeric':
        return ProblemAnswerFormat.shortNumeric;
      case 'short_answer':
        return ProblemAnswerFormat.shortAnswer;
      case 'long_solution':
        return ProblemAnswerFormat.shortAnswer;
      default:
        return null;
    }
  }
}

ProblemAnswerFormat resolveAnswerFormat(GeneratedProblem problem) {
  if (problem.isMultipleChoice) {
    return ProblemAnswerFormat.multipleChoice;
  }
  return ProblemAnswerFormat.fromApiValue(problem.answerFormat) ??
      _inferAnswerFormat(problem);
}

ProblemAnswerFormat _inferAnswerFormat(GeneratedProblem problem) {
  final prompt = '${problem.title}\n${problem.prompt}';

  if (RegExp(r'□|빈칸|채우|순서|숫자\s*하나|한\s*자리').hasMatch(prompt)) {
    return ProblemAnswerFormat.shortNumeric;
  }
  return ProblemAnswerFormat.shortAnswer;
}

String answerInputHint(ProblemAnswerFormat format) {
  switch (format) {
    case ProblemAnswerFormat.shortNumeric:
      return '예: 12, −3, 1/2';
    case ProblemAnswerFormat.shortAnswer:
      return '답을 입력하세요';
    case ProblemAnswerFormat.multipleChoice:
      return '';
  }
}

String formatDifficultyLabel(String difficulty) {
  switch (difficulty.toLowerCase()) {
    case 'easy':
      return '쉬움';
    case 'hard':
      return '어려움';
    default:
      return '보통';
  }
}

String? primaryConceptTag(List<String> tags) {
  for (final tag in tags) {
    final trimmed = tag.trim();
    if (trimmed.isNotEmpty) return trimmed;
  }
  return null;
}

/// `$24$` → `24` — 배너·짧은 피드백 표시용
String displayAnswerText(String raw) {
  return raw
      .replaceAll(r'$$', '')
      .replaceAll(r'$', '')
      .replaceAll(r'\,', '')
      .trim();
}

/// 개발 모드 디버그용 — 문제 카드에 어떤 입력·미디어 UI가 쓰였는지.
String describeProblemRender(
  GeneratedProblem problem, {
  bool hasJsx = false,
}) {
  final fmt = resolveAnswerFormat(problem);
  final api = problem.answerFormat?.trim();
  final input = api != null ? 'input:$api' : 'input:${fmt.name}(inferred)';
  final extras = <String>[];
  if (problem.chart != null) extras.add('chart');
  if (hasJsx) extras.add('jsx');
  if (extras.isEmpty) return 'render: $input';
  return 'render: $input · ${extras.join('+')}';
}

bool _looksLikeExpressionAnswer(String answer) {
  return RegExp(r'[×^=()]|\\times').hasMatch(answer) || answer.length > 20;
}

/// 식·서술형 답을 요구하는지 (UI 경고용).
bool problemNeedsExpressionInput(GeneratedProblem problem) {
  if (problem.isMultipleChoice) return false;
  if (RegExp(r'소인수분해|인수분해|완전제곱|풀이|과정|설명|서술').hasMatch(problem.prompt)) {
    return true;
  }
  return _looksLikeExpressionAnswer(problem.correctAnswer);
}
