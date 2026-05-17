/// `/api/analyze` multipart 필드 `qualityMode` 값과 동일 (enum.name)
enum AnalyzeQualityMode {
  fast,
  balanced,
  accurate,
}

class SolutionAnalysis {
  const SolutionAnalysis({
    required this.problemText,
    required this.extractedStudentAnswer,
    required this.inferredCorrectAnswer,
    required this.confidence,
    required this.solutionSteps,
    required this.errorSummary,
    required this.weakConcepts,
    required this.recommendedFocus,
    this.imageQualityWarning = false,
    this.visionImageClarityScore,
    this.visionExtractionConfidence,
  });

  factory SolutionAnalysis.fromJson(Map<String, dynamic> json) {
    return SolutionAnalysis(
      problemText: json['problemText'] as String? ?? '',
      extractedStudentAnswer: json['extractedStudentAnswer'] as String? ?? '',
      inferredCorrectAnswer: json['inferredCorrectAnswer'] as String? ?? '',
      confidence: (json['confidence'] as num? ?? 0).toDouble(),
      solutionSteps: _stringList(json['solutionSteps']),
      errorSummary: json['errorSummary'] as String? ?? '',
      weakConcepts: _stringList(json['weakConcepts']),
      recommendedFocus: _stringList(json['recommendedFocus']),
      imageQualityWarning: _readBool(json['imageQualityWarning']),
      visionImageClarityScore:
          (json['visionImageClarityScore'] as num?)?.toDouble(),
      visionExtractionConfidence:
          (json['visionExtractionConfidence'] as num?)?.toDouble(),
    );
  }

  final String problemText;
  final String extractedStudentAnswer;
  final String inferredCorrectAnswer;
  final double confidence;
  final List<String> solutionSteps;
  final String errorSummary;
  final List<String> weakConcepts;
  final List<String> recommendedFocus;
  final bool imageQualityWarning;
  final double? visionImageClarityScore;
  final double? visionExtractionConfidence;
}

class SolutionSubmission {
  const SolutionSubmission({
    required this.id,
    required this.userId,
    required this.imageUrl,
    required this.imageName,
    required this.createdAt,
    required this.analysis,
  });

  factory SolutionSubmission.fromJson(Map<String, dynamic> json) {
    return SolutionSubmission(
      id: json['id'] as String? ?? '',
      userId: json['userId'] as String? ?? '',
      imageUrl: json['imageUrl'] as String?,
      imageName: json['imageName'] as String? ?? '',
      createdAt: json['createdAt'] as String? ?? '',
      analysis: SolutionAnalysis.fromJson(
        (json['analysis'] as Map?)?.cast<String, dynamic>() ?? {},
      ),
    );
  }

  final String id;
  final String userId;
  final String? imageUrl;
  final String imageName;
  final String createdAt;
  final SolutionAnalysis analysis;
}

class ProblemChoice {
  const ProblemChoice({required this.id, required this.label});

  factory ProblemChoice.fromJson(Map<String, dynamic> json) {
    return ProblemChoice(
      id: json['id'] as String? ?? '',
      label: json['label'] as String? ?? '',
    );
  }

  final String id;
  final String label;
}

class GeneratedProblem {
  const GeneratedProblem({
    required this.id,
    required this.type,
    required this.title,
    required this.prompt,
    required this.choices,
    required this.correctAnswer,
    required this.explanation,
    required this.difficulty,
    required this.conceptTags,
    required this.chart,
    this.jsxGraph,
  });

  factory GeneratedProblem.fromJson(Map<String, dynamic> json) {
    return GeneratedProblem(
      id: json['id'] as String? ?? '',
      type: json['type'] as String? ?? 'free_response',
      title: json['title'] as String? ?? '',
      prompt: json['prompt'] as String? ?? '',
      choices: ((json['choices'] as List?) ?? [])
          .whereType<Map>()
          .map((item) => ProblemChoice.fromJson(item.cast<String, dynamic>()))
          .toList(),
      correctAnswer: json['correctAnswer'] as String? ?? '',
      explanation: json['explanation'] as String? ?? '',
      difficulty: json['difficulty'] as String? ?? 'medium',
      conceptTags: _stringList(json['conceptTags']),
      chart: (json['chart'] as Map?)?.cast<String, dynamic>(),
      jsxGraph: (json['jsxGraph'] as Map?)?.cast<String, dynamic>(),
    );
  }

  final String id;
  final String type;
  final String title;
  final String prompt;
  final List<ProblemChoice> choices;
  final String correctAnswer;
  final String explanation;
  final String difficulty;
  final List<String> conceptTags;
  final Map<String, dynamic>? chart;
  final Map<String, dynamic>? jsxGraph;

  bool get isMultipleChoice => type == 'multiple_choice' && choices.isNotEmpty;
}

class GeneratedProblemSet {
  const GeneratedProblemSet({
    required this.id,
    required this.submissionId,
    required this.title,
    required this.learningGoal,
    required this.problems,
  });

  factory GeneratedProblemSet.fromJson(Map<String, dynamic> json) {
    return GeneratedProblemSet(
      id: json['id'] as String? ?? '',
      submissionId: json['submissionId'] as String? ?? '',
      title: json['title'] as String? ?? '',
      learningGoal: json['learningGoal'] as String? ?? '',
      problems: ((json['problems'] as List?) ?? [])
          .whereType<Map>()
          .map((item) => GeneratedProblem.fromJson(item.cast<String, dynamic>()))
          .toList(),
    );
  }

  final String id;
  final String submissionId;
  final String title;
  final String learningGoal;
  final List<GeneratedProblem> problems;
}

class AnalyzeResult {
  const AnalyzeResult({
    required this.submission,
    required this.problemSet,
  });

  factory AnalyzeResult.fromJson(Map<String, dynamic> json) {
    return AnalyzeResult(
      submission: SolutionSubmission.fromJson(
        (json['submission'] as Map?)?.cast<String, dynamic>() ?? {},
      ),
      problemSet: GeneratedProblemSet.fromJson(
        (json['problemSet'] as Map?)?.cast<String, dynamic>() ?? {},
      ),
    );
  }

  final SolutionSubmission submission;
  final GeneratedProblemSet problemSet;
}

class ProblemAttempt {
  const ProblemAttempt({
    required this.id,
    required this.problemId,
    required this.answer,
    required this.isCorrect,
    required this.feedback,
  });

  factory ProblemAttempt.fromJson(Map<String, dynamic> json) {
    return ProblemAttempt(
      id: json['id'] as String? ?? '',
      problemId: json['problemId'] as String? ?? '',
      answer: json['answer'] as String? ?? '',
      isCorrect: json['isCorrect'] as bool? ?? false,
      feedback: json['feedback'] as String? ?? '',
    );
  }

  final String id;
  final String problemId;
  final String answer;
  final bool isCorrect;
  final String feedback;
}

class LearningInsight {
  const LearningInsight({
    required this.levelLabel,
    required this.masteryScore,
    required this.totalAttempts,
    required this.accuracy,
    required this.weakConcepts,
    required this.recentFeedback,
  });

  factory LearningInsight.fromJson(Map<String, dynamic> json) {
    return LearningInsight(
      levelLabel: json['levelLabel'] as String? ?? '진단 전',
      masteryScore: json['masteryScore'] as int? ?? 0,
      totalAttempts: json['totalAttempts'] as int? ?? 0,
      accuracy: json['accuracy'] as int? ?? 0,
      weakConcepts: ((json['weakConcepts'] as List?) ?? [])
          .whereType<Map>()
          .map((item) => WeakConcept.fromJson(item.cast<String, dynamic>()))
          .toList(),
      recentFeedback: _stringList(json['recentFeedback']),
    );
  }

  final String levelLabel;
  final int masteryScore;
  final int totalAttempts;
  final int accuracy;
  final List<WeakConcept> weakConcepts;
  final List<String> recentFeedback;
}

class WeakConcept {
  const WeakConcept({required this.concept, required this.misses});

  factory WeakConcept.fromJson(Map<String, dynamic> json) {
    return WeakConcept(
      concept: json['concept'] as String? ?? '',
      misses: json['misses'] as int? ?? 0,
    );
  }

  final String concept;
  final int misses;
}

List<String> _stringList(Object? value) {
  return ((value as List?) ?? []).whereType<String>().toList();
}

bool _readBool(Object? value) {
  if (value is bool) {
    return value;
  }
  if (value is int) {
    return value != 0;
  }
  if (value is String) {
    final s = value.trim().toLowerCase();
    return s == 'true' || s == '1' || s == 'yes';
  }
  return false;
}
