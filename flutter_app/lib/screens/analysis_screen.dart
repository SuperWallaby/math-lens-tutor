import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../layout/tablet_layout.dart';
import '../models/app_models.dart';
import '../services/api_client.dart';
import '../utils/problem_set_pdf.dart';
import '../widgets/app_card.dart';
import '../widgets/mixed_math_text.dart';
import '../widgets/skeleton_box.dart';
import '../widgets/skeleton_lines.dart';
import 'practice_screen.dart';

const String _weakConceptPlaceholderLegacy = '사진만으로는 부족한 개념을 특정하기 어렵습니다.';
const String _recommendedFocusPlaceholderLegacy =
    '우선 동일 유형 문제를 조금 더 풀며 풀이 과정을 적는 연습을 권합니다.';
const _kStudyReturnUser = 'study_return_user';

List<String> _meaningfulWeakConcepts(List<String> raw) {
  return raw
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty && s != _weakConceptPlaceholderLegacy)
      .toList();
}

List<String> _meaningfulRecommendedFocus(List<String> raw) {
  return raw
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty && s != _recommendedFocusPlaceholderLegacy)
      .toList();
}

class AnalysisScreen extends StatefulWidget {
  const AnalysisScreen({
    super.key,
    required this.apiClient,
    this.result,
    this.imageBytes,
    this.uploadFilename,
  }) : assert(result != null || imageBytes != null);

  final ApiClient apiClient;
  final AnalyzeResult? result;
  final Uint8List? imageBytes;
  final String? uploadFilename;

  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen> {
  String _progressMessage = '분석을 시작합니다…';
  String? _progressStep;
  SolutionAnalysis? _analysis;
  GeneratedProblemSet? _problemSet;
  AnalyzeResult? _finalResult;
  String? _error;
  bool _running = false;

  @override
  void initState() {
    super.initState();
    if (widget.result != null) {
      _finalResult = widget.result;
      _analysis = widget.result!.submission.analysis;
      _problemSet = widget.result!.problemSet;
    } else {
      _running = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _startStreamingAnalyze());
    }
  }

  String? _resolveSubmissionImageUrl() {
    final path = _finalResult?.submission.imageUrl;
    if (path == null || path.trim().isEmpty) return null;
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return path;
    }
    final base = widget.apiClient.baseUrl.replaceAll(RegExp(r'/$'), '');
    return path.startsWith('/') ? '$base$path' : '$base/$path';
  }

  int _progressRank(String? step) {
    switch (step) {
      case 'upload':
        return 1;
      case 'vision':
      case 'similar':
        return 2;
      case 'tutor':
        return 3;
      case 'save':
        return 4;
      default:
        return 0;
    }
  }

  bool _hasTutorData() =>
      _analysis?.hasTutorData ?? false;

  bool _similarStillPending() =>
      _problemSet == null || _problemSet!.problems.isEmpty;

  bool _shouldAdvanceProgress(String? nextStep) {
    if (nextStep == null) return false;
    if (nextStep == 'similar' && _progressStep == 'tutor') {
      return _hasTutorData();
    }
    final nextRank = _progressRank(nextStep);
    final curRank = _progressRank(_progressStep);
    return nextRank >= curRank;
  }

  void _maybeShowSimilarAfterTutor() {
    if (_hasTutorData() && _similarStillPending()) {
      _progressStep = 'similar';
      _progressMessage = '유사 문제 만드는 중…';
    }
  }

  void _applyStreamEvent(Map<String, dynamic> event) {
    final type = event['type'] as String?;
    final step = event['step'] as String?;
    final message = event['message'] as String?;

    if (type == 'partial') {
      if (step == 'vision' || step == 'tutor') {
        final raw = event['analysis'];
        if (raw is Map) {
          _analysis = SolutionAnalysis.fromJson(raw.cast<String, dynamic>());
        }
        if (step == 'tutor') {
          _maybeShowSimilarAfterTutor();
        }
      } else if (step == 'similar') {
        final raw = event['problemSet'];
        if (raw is Map) {
          _problemSet = GeneratedProblemSet.fromJson(raw.cast<String, dynamic>());
        }
      }
    }

    if (message != null &&
        message.isNotEmpty &&
        step != null &&
        (type == 'progress' || type == 'partial') &&
        _shouldAdvanceProgress(step)) {
      _progressStep = step;
      _progressMessage = message;
    }
  }

  Future<void> _startStreamingAnalyze() async {
    final bytes = widget.imageBytes;
    if (bytes == null) return;

    try {
      final result = await widget.apiClient.analyzeImageBytes(
        bytes,
        filename: widget.uploadFilename ?? 'upload.jpg',
        qualityMode: AnalyzeQualityMode.balanced,
        onStreamEvent: (event) {
          if (!mounted) return;
          setState(() => _applyStreamEvent(event));
        },
      );
      if (!mounted) return;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kStudyReturnUser, true);
      setState(() {
        _running = false;
        _finalResult = result;
        _analysis = result.submission.analysis;
        _problemSet = result.problemSet;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _running = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('AI 풀이 분석')),
        body: SafeArea(
          child: Padding(
            padding: TabletLayout.pagePadding(context),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(_error!, style: const TextStyle(color: Color(0xFFFCA5A5))),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('돌아가기'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final analysis = _analysis;
    final problemSet = _problemSet;
    final visionReady = analysis?.hasVisionData ?? false;
    final tutorReady = analysis?.hasTutorData ?? false;
    final similarReady = problemSet != null && problemSet.problems.isNotEmpty;

    final titleStyle = TextStyle(
      fontSize: TabletLayout.isWideTablet(context) ? 20 : 17,
      fontWeight: FontWeight.w900,
    );
    final bodyStyle = TextStyle(
      color: const Color(0xFFCBD5E1),
      height: 1.55,
      fontSize: TabletLayout.body(context),
    );

    final weakShown =
        analysis != null ? _meaningfulWeakConcepts(analysis.weakConcepts) : <String>[];
    final focusShown = analysis != null
        ? _meaningfulRecommendedFocus(analysis.recommendedFocus)
        : <String>[];
    final showTrainingSection =
        tutorReady && (weakShown.isNotEmpty || focusShown.isNotEmpty);

    final networkImageUrl = _resolveSubmissionImageUrl();

    return Scaffold(
      appBar: AppBar(title: const Text('AI 풀이 분석')),
      body: SafeArea(
        child: TabletBody(
          child: ListView(
            padding: TabletLayout.pagePadding(context),
            children: [
              AppCard(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '제출한 풀이 사진',
                      style: TextStyle(
                        color: const Color(0xFF94A3B8),
                        fontSize: TabletLayout.body(context) - 1,
                      ),
                    ),
                    if (widget.uploadFilename != null &&
                        widget.uploadFilename!.trim().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          widget.uploadFilename!,
                          style: titleStyle.copyWith(fontSize: 16),
                        ),
                      ),
                    const SizedBox(height: 10),
                    if (widget.imageBytes != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 240),
                          child: Image.memory(
                            widget.imageBytes!,
                            fit: BoxFit.contain,
                            width: double.infinity,
                          ),
                        ),
                      )
                    else if (networkImageUrl != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 240),
                          child: Image.network(
                            networkImageUrl,
                            fit: BoxFit.contain,
                            width: double.infinity,
                          loadingBuilder: (context, child, progress) {
                            if (progress == null) return child;
                            return const AspectRatio(
                              aspectRatio: 4 / 3,
                              child: Center(
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            );
                          },
                          errorBuilder: (_, __, ___) => const AspectRatio(
                            aspectRatio: 4 / 3,
                            child: Center(
                              child: Text(
                                '이미지를 불러올 수 없습니다.',
                                style: TextStyle(color: Color(0xFF94A3B8)),
                              ),
                            ),
                          ),
                          ),
                        ),
                      )
                    else
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: SkeletonLines(
                          widthFactors: [0.88, 0.72, 0.56],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              if (_running)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    _progressMessage,
                    style: const TextStyle(
                      color: Color(0xFF93C5FD),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (tutorReady && analysis != null)
                    TagChip('신뢰도 ${(analysis.confidence * 100).round()}%')
                  else
                    SkeletonBox(width: 88, height: 14, borderRadius: 999),
                  if (visionReady && analysis!.imageQualityWarning)
                    const TagChip(
                      '이미지가 흐린 것 같아요',
                      color: Color(0xFFF59E0B),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('추출한 문제', style: titleStyle),
                    const SizedBox(height: 10),
                    if (visionReady && analysis != null)
                      MixedMathText(
                        analysis.problemText,
                        style: bodyStyle,
                        readableSolutionStep: true,
                      )
                    else
                      const SkeletonLines(
                        widthFactors: SkeletonLines.paragraph,
                      ),
                    const Divider(height: 30),
                    Row(
                      children: [
                        Expanded(
                          child: _AnswerBox(
                            title: '학생 답안',
                            value: visionReady && analysis != null
                                ? analysis.extractedStudentAnswer
                                : null,
                            wide: TabletLayout.isWideTablet(context),
                            valueBold: true,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _AnswerBox(
                            title: '추정 정답',
                            value: tutorReady && analysis != null
                                ? analysis.inferredCorrectAnswer
                                : null,
                            wide: TabletLayout.isWideTablet(context),
                            valueBold: true,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('정답 풀이', style: titleStyle),
                    const SizedBox(height: 12),
                    if (tutorReady &&
                        analysis != null &&
                        analysis.referenceSolutionSteps.isNotEmpty)
                      for (final step in analysis.referenceSolutionSteps)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('• ', style: bodyStyle.copyWith(color: const Color(0xFF6EE7B7))),
                              Expanded(
                                child: MixedMathText(
                                  step,
                                  style: bodyStyle,
                                  readableSolutionStep: true,
                                ),
                              ),
                            ],
                          ),
                        )
                    else
                      const SkeletonLines(
                        widthFactors: SkeletonLines.answerSolution,
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('풀이과정', style: titleStyle),
                    const SizedBox(height: 12),
                    if (visionReady && analysis != null && analysis.solutionSteps.isNotEmpty)
                      for (final step in analysis.solutionSteps)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('• ', style: bodyStyle),
                              Expanded(
                                child: MixedMathText(
                                  step,
                                  style: bodyStyle,
                                  readableSolutionStep: true,
                                ),
                              ),
                            ],
                          ),
                        )
                    else if (visionReady)
                      Text(
                        '읽을 수 있는 손글씨 단계가 없습니다.',
                        style: bodyStyle.copyWith(color: const Color(0xFF94A3B8)),
                      )
                    else
                      const SkeletonLines(
                        widthFactors: SkeletonLines.studentSteps,
                      ),
                    if (visionReady) ...[
                      const SizedBox(height: 16),
                      const Divider(height: 1),
                      const SizedBox(height: 12),
                      Text(
                        tutorReady ? '오답 진단' : '오답 진단 중…',
                        style: TextStyle(
                          color: const Color(0xFF94A3B8),
                          fontSize: TabletLayout.body(context) - 1,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (tutorReady && analysis != null)
                        MixedMathText(
                          analysis.errorSummary,
                          style: TextStyle(
                            color: const Color(0xFFFCA5A5),
                            height: 1.5,
                            fontSize: TabletLayout.body(context),
                          ),
                          readableSolutionStep: true,
                        )
                      else
                        const SkeletonLines(
                          widthFactors: SkeletonLines.error,
                          tint: SkeletonTint.error,
                        ),
                    ],
                  ],
                ),
              ),
              if (showTrainingSection && analysis != null) ...[
                const SizedBox(height: 14),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (weakShown.isNotEmpty) ...[
                        Text('부족 개념', style: titleStyle),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final concept in weakShown) TagChip(concept),
                          ],
                        ),
                      ],
                      if (weakShown.isNotEmpty && focusShown.isNotEmpty)
                        const SizedBox(height: 16),
                      if (focusShown.isNotEmpty) ...[
                        Text('추천 훈련', style: titleStyle),
                        const SizedBox(height: 10),
                        for (final focus in focusShown)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('• ', style: bodyStyle),
                                Expanded(
                                  child: MixedMathText(focus, style: bodyStyle),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
              ] else if (!tutorReady) ...[
                const SizedBox(height: 14),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('부족 개념·추천 훈련', style: titleStyle),
                      const SizedBox(height: 12),
                      const SkeletonLines(
                        widthFactors: SkeletonLines.training,
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 18),
              if (similarReady && _finalResult != null) ...[
                OutlinedButton.icon(
                  onPressed: () async {
                    try {
                      await openSimilarProblemsPdf(_finalResult!.problemSet);
                    } catch (e) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('PDF를 만들지 못했습니다: $e')),
                      );
                    }
                  },
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                  label: const Text('유사문제 PDF로 받기'),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => PracticeScreen(
                          apiClient: widget.apiClient,
                          problemSet: _finalResult!.problemSet,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.quiz_rounded),
                  label: const Text('유사 문제 5개 풀기'),
                ),
              ] else ...[
                const SkeletonLines(widthFactors: SkeletonLines.button),
                const SizedBox(height: 12),
                const SkeletonLines(widthFactors: [0.72]),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _AnswerBox extends StatelessWidget {
  const _AnswerBox({
    required this.title,
    required this.value,
    required this.wide,
    this.valueBold = false,
  });

  final String title;
  final String? value;
  final bool wide;
  final bool valueBold;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(wide ? 16 : 12),
      decoration: BoxDecoration(
        color: const Color(0xFF020617),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: const Color(0xFF94A3B8),
              fontSize: wide ? 14 : 12,
            ),
          ),
          const SizedBox(height: 8),
          if (value != null && value!.trim().isNotEmpty)
          MixedMathText(
            value!,
            style: TextStyle(
              color: Colors.white,
              fontWeight: valueBold ? FontWeight.w800 : FontWeight.w600,
              fontSize: wide ? 18 : 16,
            ),
            readableSolutionStep: true,
            paragraphSoftBreak: title == '추정 정답',
          )
          else
            SkeletonLines(
              widthFactors: title == '추정 정답'
                  ? const [0.68, 0.52]
                  : SkeletonLines.short,
              lineHeight: wide ? 14 : 12,
              gap: 6,
            ),
        ],
      ),
    );
  }
}
