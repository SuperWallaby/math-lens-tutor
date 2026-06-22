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
    this.referenceSolutionSteps = const [],
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
      referenceSolutionSteps: _stringList(json['referenceSolutionSteps']),
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
  final List<String> referenceSolutionSteps;
  final String errorSummary;
  final List<String> weakConcepts;
  final List<String> recommendedFocus;
  final bool imageQualityWarning;
  final double? visionImageClarityScore;
  final double? visionExtractionConfidence;

  bool get hasVisionData =>
      problemText.trim().isNotEmpty ||
      extractedStudentAnswer.trim().isNotEmpty ||
      solutionSteps.isNotEmpty;

  bool get hasTutorData =>
      inferredCorrectAnswer.trim().isNotEmpty && errorSummary.trim().isNotEmpty;
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
    this.answerFormat,
    this.source = 'generated',
    this.bankItemId,
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
      answerFormat: json['answerFormat'] as String?,
      source: json['source'] as String? ?? 'generated',
      bankItemId: json['bankItemId'] as String?,
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
  /// `short_numeric` | `short_answer` | `long_solution` (free_response only)
  final String? answerFormat;
  final String source;
  final String? bankItemId;

  bool get isMultipleChoice => type == 'multiple_choice' && choices.isNotEmpty;
  bool get isFromBank => source == 'bank';
}

class PracticeAvailabilityPreview {
  const PracticeAvailabilityPreview({
    required this.bankCount,
    required this.setSize,
    required this.needsGeneration,
    required this.generateCount,
  });

  factory PracticeAvailabilityPreview.fromJson(Map<String, dynamic> json) {
    return PracticeAvailabilityPreview(
      bankCount: json['bankCount'] as int? ?? 0,
      setSize: json['setSize'] as int? ?? 5,
      needsGeneration: json['needsGeneration'] as bool? ?? true,
      generateCount: json['generateCount'] as int? ?? 0,
    );
  }

  final int bankCount;
  final int setSize;
  final bool needsGeneration;
  final int generateCount;
}

class StartPracticeResult {
  const StartPracticeResult({
    required this.problemSet,
    required this.meta,
  });

  factory StartPracticeResult.fromJson(Map<String, dynamic> json) {
    return StartPracticeResult(
      problemSet: GeneratedProblemSet.fromJson(
        (json['problemSet'] as Map).cast<String, dynamic>(),
      ),
      meta: PracticeAvailabilityPreview.fromJson(
        (json['meta'] as Map?)?.cast<String, dynamic>() ??
            const {
              'bankCount': 0,
              'setSize': 5,
              'needsGeneration': true,
              'generateCount': 5,
            },
      ),
    );
  }

  final GeneratedProblemSet problemSet;
  final PracticeAvailabilityPreview meta;
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
    this.relearnedConcepts = const [],
  });

  factory ProblemAttempt.fromJson(Map<String, dynamic> json) {
    return ProblemAttempt(
      id: json['id'] as String? ?? '',
      problemId: json['problemId'] as String? ?? '',
      answer: json['answer'] as String? ?? '',
      isCorrect: json['isCorrect'] as bool? ?? false,
      feedback: json['feedback'] as String? ?? '',
      relearnedConcepts: _stringList(json['relearnedConcepts']),
    );
  }

  final String id;
  final String problemId;
  final String answer;
  final bool isCorrect;
  final String feedback;
  final List<String> relearnedConcepts;
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

enum AppUserRole { student, parent, teacher }

extension AppUserRoleX on AppUserRole {
  String get apiValue => name;

  static AppUserRole? fromApi(String? value) {
    switch (value) {
      case 'student':
        return AppUserRole.student;
      case 'parent':
        return AppUserRole.parent;
      case 'teacher':
        return AppUserRole.teacher;
      default:
        return null;
    }
  }

  String get label {
    switch (this) {
      case AppUserRole.student:
        return '학생';
      case AppUserRole.parent:
        return '학부모';
      case AppUserRole.teacher:
        return '교사';
    }
  }

  bool get isGuardian =>
      this == AppUserRole.parent || this == AppUserRole.teacher;
}

class AppUser {
  const AppUser({
    required this.id,
    required this.displayName,
    required this.profileComplete,
    this.role,
    this.age,
    this.grade,
    this.organizationName,
    this.studentCode,
    this.oauthProvider,
    this.email,
    this.profileImageUrl,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'] as String? ?? '',
      displayName: json['displayName'] as String? ?? '',
      profileComplete: json['profileComplete'] as bool? ?? false,
      role: AppUserRoleX.fromApi(json['role'] as String?),
      age: (json['age'] as num?)?.toInt(),
      grade: json['grade'] as String?,
      organizationName: json['organizationName'] as String?,
      studentCode: json['studentCode'] as String?,
      oauthProvider: json['oauthProvider'] as String?,
      email: json['email'] as String?,
      profileImageUrl: json['profileImageUrl'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'displayName': displayName,
    'profileComplete': profileComplete,
    'role': role?.apiValue,
    'age': age,
    'grade': grade,
    'organizationName': organizationName,
    'studentCode': studentCode,
    'oauthProvider': oauthProvider,
    'email': email,
    'profileImageUrl': profileImageUrl,
  };

  AppUser copyWith({
    String? displayName,
    bool? profileComplete,
    AppUserRole? role,
    int? age,
    String? grade,
    String? organizationName,
    String? studentCode,
    String? profileImageUrl,
  }) {
    return AppUser(
      id: id,
      displayName: displayName ?? this.displayName,
      profileComplete: profileComplete ?? this.profileComplete,
      role: role ?? this.role,
      age: age ?? this.age,
      grade: grade ?? this.grade,
      organizationName: organizationName ?? this.organizationName,
      studentCode: studentCode ?? this.studentCode,
      oauthProvider: oauthProvider,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
    );
  }

  final String id;
  final String displayName;
  final bool profileComplete;
  final AppUserRole? role;
  final int? age;
  final String? grade;
  final String? organizationName;
  final String? studentCode;
  final String? oauthProvider;
  final String? email;
  final String? profileImageUrl;

  bool get isGuardian => role?.isGuardian ?? false;
  bool get isStudent => role == AppUserRole.student;
  bool get isTeacher => role == AppUserRole.teacher;
}

class LinkedStudent {
  const LinkedStudent({
    required this.id,
    required this.displayName,
    required this.studentCode,
  });

  factory LinkedStudent.fromJson(Map<String, dynamic> json) {
    return LinkedStudent(
      id: json['id'] as String? ?? '',
      displayName: json['displayName'] as String? ?? '',
      studentCode: json['studentCode'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'displayName': displayName,
    'studentCode': studentCode,
  };

  final String id;
  final String displayName;
  final String studentCode;
}

class SubmissionSummary {
  const SubmissionSummary({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.weakConcepts,
    this.imageUrl,
    this.imageName = '',
  });

  factory SubmissionSummary.fromJson(Map<String, dynamic> json) {
    final legacyTitle = (json['imageName'] as String? ?? '').trim();
    final title = (json['title'] as String? ?? '').trim();

    return SubmissionSummary(
      id: json['id'] as String? ?? '',
      title: title.isNotEmpty
          ? title
          : (legacyTitle.isNotEmpty ? legacyTitle : '풀이 분석'),
      createdAt: json['createdAt'] as String? ?? '',
      imageUrl: json['imageUrl'] as String?,
      imageName: json['imageName'] as String? ?? '',
      weakConcepts: _stringList(json['weakConcepts']),
    );
  }

  final String id;
  final String title;
  final String createdAt;
  final String? imageUrl;
  final String imageName;
  final List<String> weakConcepts;
}

class TrainingFocusItem {
  const TrainingFocusItem({
    required this.concept,
    required this.missScore,
    required this.status,
    required this.label,
  });

  factory TrainingFocusItem.fromJson(Map<String, dynamic> json) {
    return TrainingFocusItem(
      concept: json['concept'] as String? ?? '',
      missScore: json['missScore'] as int? ?? 0,
      status: json['status'] as String? ?? 'needs_training',
      label: json['label'] as String? ?? '',
    );
  }

  final String concept;
  final int missScore;
  final String status;
  final String label;

  bool get isRelearned => status == 'relearned';
}

class TrainingSnapshot {
  const TrainingSnapshot({
    required this.available,
    required this.hasLearningData,
    required this.headline,
    required this.description,
    required this.focusConcepts,
    required this.focusItems,
    required this.activeSetId,
    required this.remainingCount,
    required this.totalMisses,
    required this.relearnedCount,
  });

  factory TrainingSnapshot.fromJson(Map<String, dynamic> json) {
    return TrainingSnapshot(
      available: json['available'] as bool? ?? false,
      hasLearningData: json['hasLearningData'] as bool? ?? false,
      headline: json['headline'] as String? ?? '',
      description: json['description'] as String? ?? '',
      focusConcepts: _stringList(json['focusConcepts']),
      focusItems: ((json['focusItems'] as List?) ?? [])
          .whereType<Map>()
          .map((e) => TrainingFocusItem.fromJson(e.cast<String, dynamic>()))
          .toList(),
      activeSetId: json['activeSetId'] as String?,
      remainingCount: json['remainingCount'] as int? ?? 0,
      totalMisses: json['totalMisses'] as int? ?? 0,
      relearnedCount: json['relearnedCount'] as int? ?? 0,
    );
  }

  static const empty = TrainingSnapshot(
    available: false,
    hasLearningData: false,
    headline: '',
    description: '',
    focusConcepts: [],
    focusItems: [],
    activeSetId: null,
    remainingCount: 0,
    totalMisses: 0,
    relearnedCount: 0,
  );

  final bool available;
  final bool hasLearningData;
  final String headline;
  final String description;
  final List<String> focusConcepts;
  final List<TrainingFocusItem> focusItems;
  final String? activeSetId;
  final int remainingCount;
  final int totalMisses;
  final int relearnedCount;
}

class TrainingFeedItem {
  const TrainingFeedItem({
    required this.id,
    required this.bankItemId,
    required this.concept,
    required this.difficulty,
    required this.reason,
    required this.title,
    required this.promptPreview,
  });

  factory TrainingFeedItem.fromJson(Map<String, dynamic> json) {
    return TrainingFeedItem(
      id: json['id'] as String? ?? '',
      bankItemId: json['bankItemId'] as String? ?? '',
      concept: json['concept'] as String? ?? '',
      difficulty: json['difficulty'] as String? ?? 'medium',
      reason: json['reason'] as String? ?? '',
      title: json['title'] as String? ?? '',
      promptPreview: json['promptPreview'] as String? ?? '',
    );
  }

  final String id;
  final String bankItemId;
  final String concept;
  final String difficulty;
  final String reason;
  final String title;
  final String promptPreview;

  String get difficultyLabel {
    switch (difficulty) {
      case 'easy':
        return '쉬움';
      case 'hard':
        return '어려움';
      default:
        return '보통';
    }
  }
}

class TrainingFeedResponse {
  const TrainingFeedResponse({
    required this.items,
    required this.source,
    required this.updatedAt,
    required this.refreshPending,
  });

  factory TrainingFeedResponse.fromJson(Map<String, dynamic> json) {
    return TrainingFeedResponse(
      items: ((json['items'] as List?) ?? [])
          .whereType<Map>()
          .map((e) => TrainingFeedItem.fromJson(e.cast<String, dynamic>()))
          .toList(),
      source: json['source'] as String? ?? 'fallback',
      updatedAt: json['updatedAt'] as String?,
      refreshPending: json['refreshPending'] as bool? ?? false,
    );
  }

  final List<TrainingFeedItem> items;
  final String source;
  final String? updatedAt;
  final bool refreshPending;

  bool get isPrecomputed => source == 'precomputed';
}

class LearningProfile {
  const LearningProfile({
    required this.grade,
    required this.insight,
    required this.stats,
    required this.conceptStatus,
    required this.strongConcepts,
    required this.weeklyTrend,
    required this.curriculumUnits,
    required this.curriculumByBand,
    required this.parentActions,
    required this.weeklyReport,
    required this.training,
    this.mission,
    this.chainWarning,
    this.parentCoachingCard,
    this.parentWrongExplains = const [],
  });

  factory LearningProfile.fromJson(Map<String, dynamic> json) {
    final curriculumUnits = ((json['curriculumUnits'] as List?) ?? [])
        .whereType<Map>()
        .map((e) => CurriculumUnitProgress.fromJson(e.cast<String, dynamic>()))
        .toList();
    final byBandRaw = json['curriculumByBand'];
    final curriculumByBand = byBandRaw is Map
        ? byBandRaw.map(
            (key, value) => MapEntry(
              key.toString(),
              ((value as List?) ?? [])
                  .whereType<Map>()
                  .map(
                    (e) => CurriculumUnitProgress.fromJson(
                      e.cast<String, dynamic>(),
                    ),
                  )
                  .toList(),
            ),
          )
        : <String, List<CurriculumUnitProgress>>{};

    return LearningProfile(
      grade: json['grade'] as String? ?? '중1',
      insight: LearningInsight.fromJson(
        (json['insight'] as Map?)?.cast<String, dynamic>() ?? {},
      ),
      stats: LearningStats.fromJson(
        (json['stats'] as Map?)?.cast<String, dynamic>() ?? {},
      ),
      mission: json['mission'] == null
          ? null
          : TodayMission.fromJson(
              (json['mission'] as Map).cast<String, dynamic>(),
            ),
      conceptStatus: ((json['conceptStatus'] as List?) ?? [])
          .whereType<Map>()
          .map((e) => ConceptStatusItem.fromJson(e.cast<String, dynamic>()))
          .toList(),
      strongConcepts: ((json['strongConcepts'] as List?) ?? [])
          .whereType<Map>()
          .map((e) => StrongConcept.fromJson(e.cast<String, dynamic>()))
          .toList(),
      weeklyTrend: ((json['weeklyTrend'] as List?) ?? [])
          .whereType<Map>()
          .map((e) => WeeklyTrendPoint.fromJson(e.cast<String, dynamic>()))
          .toList(),
      curriculumUnits: curriculumUnits,
      curriculumByBand: curriculumByBand,
      chainWarning: json['chainWarning'] as String?,
      parentActions: ((json['parentActions'] as List?) ?? [])
          .whereType<Map>()
          .map((e) => ParentActionItem.fromJson(e.cast<String, dynamic>()))
          .toList(),
      parentCoachingCard: json['parentCoachingCard'] == null
          ? null
          : ParentCoachingCard.fromJson(
              (json['parentCoachingCard'] as Map).cast<String, dynamic>(),
            ),
      parentWrongExplains: ((json['parentWrongExplains'] as List?) ?? [])
          .whereType<Map>()
          .map((e) => ParentWrongExplainItem.fromJson(e.cast<String, dynamic>()))
          .toList(),
      weeklyReport: WeeklyReport.fromJson(
        (json['weeklyReport'] as Map?)?.cast<String, dynamic>() ?? {},
      ),
      training: json['training'] == null
          ? TrainingSnapshot.empty
          : TrainingSnapshot.fromJson(
              (json['training'] as Map).cast<String, dynamic>(),
            ),
    );
  }

  final String grade;
  final LearningInsight insight;
  final LearningStats stats;
  final TodayMission? mission;
  final TrainingSnapshot training;
  final List<ConceptStatusItem> conceptStatus;
  final List<StrongConcept> strongConcepts;
  final List<WeeklyTrendPoint> weeklyTrend;
  final List<CurriculumUnitProgress> curriculumUnits;
  final Map<String, List<CurriculumUnitProgress>> curriculumByBand;
  final String? chainWarning;
  final List<ParentActionItem> parentActions;
  final ParentCoachingCard? parentCoachingCard;
  final List<ParentWrongExplainItem> parentWrongExplains;
  final WeeklyReport weeklyReport;

  List<CurriculumUnitProgress> unitsForGradeTab(int tabIndex) {
    const keys = ['e12', 'e34', 'e56', 'm1', 'm2', 'm3', 'h1', 'h2', 'h3'];
    if (tabIndex < 0 || tabIndex >= keys.length) {
      return curriculumUnits;
    }
    return curriculumByBand[keys[tabIndex]] ?? curriculumUnits;
  }
}

class LearningStats {
  const LearningStats({
    required this.accuracy,
    required this.accuracyDelta,
    required this.totalProblems,
    required this.problemsDelta,
    required this.streakWeeks,
  });

  factory LearningStats.fromJson(Map<String, dynamic> json) {
    return LearningStats(
      accuracy: json['accuracy'] as int? ?? 0,
      accuracyDelta: json['accuracyDelta'] as int? ?? 0,
      totalProblems: json['totalProblems'] as int? ?? 0,
      problemsDelta: json['problemsDelta'] as int? ?? 0,
      streakWeeks: json['streakWeeks'] as int? ?? 0,
    );
  }

  final int accuracy;
  final int accuracyDelta;
  final int totalProblems;
  final int problemsDelta;
  final int streakWeeks;
}

class TodayMission {
  const TodayMission({
    required this.title,
    required this.subtitle,
    required this.remainingCount,
    required this.setId,
    required this.conceptTags,
  });

  factory TodayMission.fromJson(Map<String, dynamic> json) {
    return TodayMission(
      title: json['title'] as String? ?? '',
      subtitle: json['subtitle'] as String? ?? '',
      remainingCount: json['remainingCount'] as int? ?? 0,
      setId: json['setId'] as String?,
      conceptTags: _stringList(json['conceptTags']),
    );
  }

  final String title;
  final String subtitle;
  final int remainingCount;
  final String? setId;
  final List<String> conceptTags;
}

class ConceptStatusItem {
  const ConceptStatusItem({
    required this.concept,
    required this.misses,
    required this.status,
    required this.label,
  });

  factory ConceptStatusItem.fromJson(Map<String, dynamic> json) {
    return ConceptStatusItem(
      concept: json['concept'] as String? ?? '',
      misses: json['misses'] as int? ?? 0,
      status: json['status'] as String? ?? 'learning',
      label: json['label'] as String? ?? '',
    );
  }

  final String concept;
  final int misses;
  final String status;
  final String label;
}

class StrongConcept {
  const StrongConcept({required this.concept, required this.score});

  factory StrongConcept.fromJson(Map<String, dynamic> json) {
    return StrongConcept(
      concept: json['concept'] as String? ?? '',
      score: json['score'] as int? ?? 0,
    );
  }

  final String concept;
  final int score;
}

class WeeklyTrendPoint {
  const WeeklyTrendPoint({
    required this.weekLabel,
    required this.accuracy,
    required this.summary,
  });

  factory WeeklyTrendPoint.fromJson(Map<String, dynamic> json) {
    return WeeklyTrendPoint(
      weekLabel: json['weekLabel'] as String? ?? '',
      accuracy: json['accuracy'] as int? ?? 0,
      summary: json['summary'] as String? ?? '',
    );
  }

  final String weekLabel;
  final int accuracy;
  final String summary;
}

class CurriculumUnitProgress {
  const CurriculumUnitProgress({
    required this.id,
    required this.section,
    required this.name,
    required this.subtitle,
    required this.percent,
    required this.status,
  });

  factory CurriculumUnitProgress.fromJson(Map<String, dynamic> json) {
    return CurriculumUnitProgress(
      id: json['id'] as String? ?? '',
      section: json['section'] as String? ?? '',
      name: json['name'] as String? ?? '',
      subtitle: json['subtitle'] as String? ?? '',
      percent: json['percent'] as int? ?? 0,
      status: json['status'] as String? ?? 'none',
    );
  }

  final String id;
  final String section;
  final String name;
  final String subtitle;
  final int percent;
  final String status;
}

class ParentActionItem {
  const ParentActionItem({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  factory ParentActionItem.fromJson(Map<String, dynamic> json) {
    return ParentActionItem(
      icon: json['icon'] as String? ?? '',
      title: json['title'] as String? ?? '',
      subtitle: json['subtitle'] as String? ?? '',
    );
  }

  final String icon;
  final String title;
  final String subtitle;
}

class ParentCoachingCard {
  const ParentCoachingCard({
    required this.label,
    required this.question,
    required this.gradingPoint,
    required this.context,
    required this.sourceType,
    required this.sourceId,
    required this.problemLabel,
  });

  factory ParentCoachingCard.fromJson(Map<String, dynamic> json) {
    return ParentCoachingCard(
      label: json['label'] as String? ?? '오늘의 부모 코칭',
      question: json['question'] as String? ?? '',
      gradingPoint: json['gradingPoint'] as String? ?? '',
      context: json['context'] as String? ?? '',
      sourceType: json['sourceType'] as String? ?? 'fallback',
      sourceId: json['sourceId'] as String?,
      problemLabel: json['problemLabel'] as String?,
    );
  }

  final String label;
  final String question;
  final String gradingPoint;
  final String context;
  final String sourceType;
  final String? sourceId;
  final String? problemLabel;
}

class ParentWrongExplainItem {
  const ParentWrongExplainItem({
    required this.id,
    required this.sourceType,
    required this.sourceId,
    required this.title,
    required this.concept,
    required this.easyExplain,
    required this.parentScript,
    required this.problemSetId,
    required this.createdAt,
  });

  factory ParentWrongExplainItem.fromJson(Map<String, dynamic> json) {
    return ParentWrongExplainItem(
      id: json['id'] as String? ?? '',
      sourceType: json['sourceType'] as String? ?? 'submission',
      sourceId: json['sourceId'] as String? ?? '',
      title: json['title'] as String? ?? '',
      concept: json['concept'] as String? ?? '',
      easyExplain: json['easyExplain'] as String? ?? '',
      parentScript: json['parentScript'] as String? ?? '',
      problemSetId: json['problemSetId'] as String?,
      createdAt: json['createdAt'] as String? ?? '',
    );
  }

  final String id;
  final String sourceType;
  final String sourceId;
  final String title;
  final String concept;
  final String easyExplain;
  final String parentScript;
  final String? problemSetId;
  final String createdAt;
}

class WeeklyReport {
  const WeeklyReport({
    required this.weekLabel,
    required this.period,
    required this.cycle,
    required this.unitMastery,
  });

  factory WeeklyReport.fromJson(Map<String, dynamic> json) {
    return WeeklyReport(
      weekLabel: json['weekLabel'] as String? ?? '',
      period: json['period'] as String? ?? '',
      cycle: ((json['cycle'] as List?) ?? [])
          .whereType<Map>()
          .map((e) => WeeklyReportStep.fromJson(e.cast<String, dynamic>()))
          .toList(),
      unitMastery: ((json['unitMastery'] as List?) ?? [])
          .whereType<Map>()
          .map((e) => UnitMastery.fromJson(e.cast<String, dynamic>()))
          .toList(),
    );
  }

  final String weekLabel;
  final String period;
  final List<WeeklyReportStep> cycle;
  final List<UnitMastery> unitMastery;
}

class WeeklyReportStep {
  const WeeklyReportStep({
    required this.step,
    required this.label,
    required this.title,
    required this.text,
  });

  factory WeeklyReportStep.fromJson(Map<String, dynamic> json) {
    return WeeklyReportStep(
      step: json['step'] as int? ?? 0,
      label: json['label'] as String? ?? '',
      title: json['title'] as String? ?? '',
      text: json['text'] as String? ?? '',
    );
  }

  final int step;
  final String label;
  final String title;
  final String text;
}

class UnitMastery {
  const UnitMastery({required this.name, required this.percent});

  factory UnitMastery.fromJson(Map<String, dynamic> json) {
    return UnitMastery(
      name: json['name'] as String? ?? '',
      percent: json['percent'] as int? ?? 0,
    );
  }

  final String name;
  final int percent;
}

class TeacherClassOverview {
  const TeacherClassOverview({
    required this.totalStudents,
    required this.atRiskCount,
    required this.classAverageAccuracy,
    required this.accuracyDelta,
    required this.dangerStudents,
    required this.students,
    required this.classUnitAverages,
    required this.recommendations,
    this.organizationName,
  });

  factory TeacherClassOverview.fromJson(Map<String, dynamic> json) {
    return TeacherClassOverview(
      totalStudents: json['totalStudents'] as int? ?? 0,
      atRiskCount: json['atRiskCount'] as int? ?? 0,
      classAverageAccuracy: json['classAverageAccuracy'] as int? ?? 0,
      accuracyDelta: json['accuracyDelta'] as int? ?? 0,
      organizationName: json['organizationName'] as String?,
      dangerStudents: ((json['dangerStudents'] as List?) ?? [])
          .whereType<Map>()
          .map((e) => TeacherStudentRow.fromJson(e.cast<String, dynamic>()))
          .toList(),
      students: ((json['students'] as List?) ?? [])
          .whereType<Map>()
          .map((e) => TeacherStudentRow.fromJson(e.cast<String, dynamic>()))
          .toList(),
      classUnitAverages: ((json['classUnitAverages'] as List?) ?? [])
          .whereType<Map>()
          .map((e) => UnitMastery.fromJson(e.cast<String, dynamic>()))
          .toList(),
      recommendations: ((json['recommendations'] as List?) ?? [])
          .whereType<Map>()
          .map((e) => ParentActionItem.fromJson(e.cast<String, dynamic>()))
          .toList(),
    );
  }

  final int totalStudents;
  final int atRiskCount;
  final int classAverageAccuracy;
  final int accuracyDelta;
  final String? organizationName;
  final List<TeacherStudentRow> dangerStudents;
  final List<TeacherStudentRow> students;
  final List<UnitMastery> classUnitAverages;
  final List<ParentActionItem> recommendations;
}

class TeacherStudentRow {
  const TeacherStudentRow({
    required this.id,
    required this.displayName,
    required this.studentCode,
    required this.accuracy,
    required this.status,
    required this.statusLabel,
    required this.weakConcept,
    required this.totalAttempts,
  });

  factory TeacherStudentRow.fromJson(Map<String, dynamic> json) {
    return TeacherStudentRow(
      id: json['id'] as String? ?? '',
      displayName: json['displayName'] as String? ?? '',
      studentCode: json['studentCode'] as String? ?? '',
      accuracy: json['accuracy'] as int? ?? 0,
      status: json['status'] as String? ?? 'normal',
      statusLabel: json['statusLabel'] as String? ?? '',
      weakConcept: json['weakConcept'] as String? ?? '',
      totalAttempts: json['totalAttempts'] as int? ?? 0,
    );
  }

  final String id;
  final String displayName;
  final String studentCode;
  final int accuracy;
  final String status;
  final String statusLabel;
  final String weakConcept;
  final int totalAttempts;
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
