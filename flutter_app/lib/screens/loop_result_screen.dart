import 'package:flutter/material.dart';

import '../layout/tablet_layout.dart';
import '../models/app_models.dart';
import '../services/api_client.dart';
import '../utils/problem_answer_format.dart';
import '../widgets/app_card.dart';
import '../widgets/hero_icon_3d.dart';
import '../widgets/learning_profile_widgets.dart';
import '../widgets/mixed_math_text.dart';
import 'practice_screen.dart';
import '../theme/app_design_system.dart';

class LoopResultScreen extends StatefulWidget {
  const LoopResultScreen({
    super.key,
    required this.apiClient,
    required this.problemSet,
    required this.feedback,
  });

  final ApiClient apiClient;
  final GeneratedProblemSet problemSet;
  final Map<String, ProblemAttempt> feedback;

  @override
  State<LoopResultScreen> createState() => _LoopResultScreenState();
}

class _LoopResultScreenState extends State<LoopResultScreen> {
  bool _retryLoading = false;
  String? _retryError;

  int get _correctCount =>
      widget.feedback.values.where((a) => a.isCorrect).length;

  int get _totalCount => widget.problemSet.problems.length;

  int get _accuracyPercent =>
      _totalCount == 0 ? 0 : ((_correctCount / _totalCount) * 100).round();

  List<_ProblemResult> get _allResults {
    final items = <_ProblemResult>[];
    for (var i = 0; i < widget.problemSet.problems.length; i++) {
      final problem = widget.problemSet.problems[i];
      final attempt = widget.feedback[problem.id];
      if (attempt == null) continue;
      items.add(
        _ProblemResult(index: i + 1, problem: problem, attempt: attempt),
      );
    }
    return items;
  }

  List<_ProblemResult> get _wrongResults =>
      _allResults.where((r) => !r.attempt.isCorrect).toList();

  List<_ProblemResult> get _correctResults =>
      _allResults.where((r) => r.attempt.isCorrect).toList();

  String? get _confusionInsight => buildPracticeConfusionInsight(
        wrongConcepts: _wrongResults
            .map((r) => primaryConceptTag(r.problem.conceptTags))
            .whereType<String>()
            .toList(),
        correctConcepts: _correctResults
            .map((r) => primaryConceptTag(r.problem.conceptTags))
            .whereType<String>()
            .toList(),
      );

  _ResultPresentation _resultPresentation() {
    final correct = _correctCount;
    final total = _totalCount;
    final wrong = total - correct;
    final ratio = total == 0 ? 0.0 : correct / total;

    if (correct == total && total > 0) {
      return _ResultPresentation(
        tone: AppColors.success,
        iconAsset: 'assets/icons/3d/loop_result_perfect.png',
        title: '완벽해요!',
        message: '이 개념은 충분히 이해했어요.',
      );
    }
    if (ratio >= 0.8) {
      return _ResultPresentation(
        tone: AppColors.primary,
        iconAsset: 'assets/icons/3d/loop_result_perfect.png',
        title: '거의 다 맞혔어요',
        message: wrong > 0
            ? '틀린 $wrong문제만 다시 보면 완벽해져요.'
            : '조금만 더 연습하면 완벽해져요.',
      );
    }
    if (ratio >= 0.4) {
      return _ResultPresentation(
        tone: AppColors.warning,
        iconAsset: 'assets/icons/3d/loop_result_partial.png',
        title: '조금 더 연습해요',
        message: wrong > 0
            ? '틀린 $wrong문제를 확인하고 같은 유형으로 다시 도전해 보세요.'
            : '같은 유형으로 한 번 더 연습해 보세요.',
      );
    }
    return _ResultPresentation(
      tone: AppColors.accent,
      iconAsset: 'assets/icons/3d/loop_result_partial.png',
      title: '다시 도전해요',
      message: wrong > 0
          ? '틀린 $wrong문제 개념을 집중해서 복습해 보세요.'
          : '같은 유형 문제로 다시 연습해 보세요.',
    );
  }

  Future<void> _retry() async {
    setState(() {
      _retryLoading = true;
      _retryError = null;
    });

    try {
      final newSet = await widget.apiClient.retryPractice(
        submissionId: widget.problemSet.submissionId,
        previousSetId: widget.problemSet.id,
      );
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => PracticeScreen(
            apiClient: widget.apiClient,
            problemSet: newSet,
          ),
        ),
      );
    } on ApiException catch (e) {
      setState(() => _retryError = e.message);
    } catch (e) {
      setState(() => _retryError = e.toString());
    } finally {
      if (mounted) setState(() => _retryLoading = false);
    }
  }

  void _openProblemReviewSheet(_ProblemResult item) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.lg)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.72,
          minChildSize: 0.4,
          maxChildSize: 0.92,
          builder: (context, scrollController) {
            return Column(
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.borderStrong,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '문제 ${item.index}번 · ${_compactResultLabel(item.attempt.isCorrect)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 17,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: AppColors.border),
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: TabletLayout.pagePadding(context),
                    children: [_ProblemReviewCard(item: item)],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final insight = _confusionInsight;
    final presentation = _resultPresentation();
    final wide = TabletLayout.isWideTablet(context);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.text,
        title: const Text('훈련 결과'),
      ),
      body: SafeArea(
        child: TabletBody(
          child: ListView(
            padding: TabletLayout.pagePadding(context),
            children: [
              _ResultHeroCard(
                correctCount: _correctCount,
                totalCount: _totalCount,
                accuracyPercent: _accuracyPercent,
                presentation: presentation,
                wide: wide,
              ),
              if (insight != null) ...[
                const SectionLabel('AI 피드백'),
                _AiFeedbackCard(message: insight),
              ],
              const SectionLabel('문제별 결과'),
              for (final item in _allResults) ...[
                _ProblemResultCard(
                  item: item,
                  onView: () => _openProblemReviewSheet(item),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
              if (_retryError != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  _retryError!,
                  style: const TextStyle(color: AppColors.accent, height: 1.4),
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _retryLoading ? null : _retry,
                  icon: _retryLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh_rounded),
                  label: Text(_retryLoading ? '새 문제 불러오는 중…' : '새 문제로 다시 도전'),
                  style: FilledButton.styleFrom(
                    minimumSize:
                        const Size.fromHeight(AppSizes.buttonHeightKeyAction),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () =>
                      Navigator.of(context).popUntil((route) => route.isFirst),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(AppSizes.buttonHeight),
                  ),
                  child: const Text('나중에 하기'),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResultPresentation {
  const _ResultPresentation({
    required this.tone,
    required this.iconAsset,
    required this.title,
    required this.message,
  });

  final Color tone;
  final String iconAsset;
  final String title;
  final String message;
}

class _ResultHeroCard extends StatelessWidget {
  const _ResultHeroCard({
    required this.correctCount,
    required this.totalCount,
    required this.accuracyPercent,
    required this.presentation,
    required this.wide,
  });

  final int correctCount;
  final int totalCount;
  final int accuracyPercent;
  final _ResultPresentation presentation;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final tone = presentation.tone;
    final scoreSize = wide ? 56.0 : 48.0;
    final suffixSize = wide ? 30.0 : 26.0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.lg),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            tone.withValues(alpha: 0.18),
            tone.withValues(alpha: 0.06),
          ],
        ),
        border: Border.all(color: tone.withValues(alpha: 0.28)),
      ),
      child: Column(
        children: [
          HeroIcon3d(
            asset: presentation.iconAsset,
            size: wide ? 104 : 92,
            iconSize: wide ? 68 : 60,
            tint: tone,
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '$correctCount',
                style: TextStyle(
                  color: tone,
                  fontSize: scoreSize,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
              Text(
                '/$totalCount',
                style: TextStyle(
                  color: AppColors.textSub,
                  fontSize: suffixSize,
                  fontWeight: FontWeight.w800,
                  height: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: tone.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(AppRadii.pill),
            ),
            child: Text(
              '$accuracyPercent% 정답률',
              style: TextStyle(
                color: tone,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            presentation.title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.text,
              fontSize: wide ? 20 : 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            presentation.message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textSub,
              height: 1.5,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _AiFeedbackCard extends StatelessWidget {
  const _AiFeedbackCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HeroIcon3d(
            asset: 'assets/icons/3d/weak_concept_alert.png',
            size: 56,
            iconSize: 36,
            tint: AppColors.primary,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '학습 포인트',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  message,
                  style: const TextStyle(
                    color: AppColors.text,
                    height: 1.55,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProblemResultCard extends StatelessWidget {
  const _ProblemResultCard({
    required this.item,
    required this.onView,
  });

  final _ProblemResult item;
  final VoidCallback onView;

  @override
  Widget build(BuildContext context) {
    final ok = item.attempt.isCorrect;
    final concept = primaryConceptTag(item.problem.conceptTags);
    final statusColor =
        ok ? AppColors.success.withValues(alpha: 0.7) : AppColors.borderStrong;

    return AppCard(
      padding: EdgeInsets.zero,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 3,
              decoration: BoxDecoration(
                color: statusColor,
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(AppRadii.md),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _CompactResultLabel(isCorrect: ok),
                        const Spacer(),
                        Text(
                          '${item.index}번',
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      item.problem.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: AppColors.text,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    _ProblemMetaText(
                      difficulty: formatDifficultyLabel(item.problem.difficulty),
                      concept: concept,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: onView,
                        icon: const Icon(Icons.visibility_outlined, size: 16),
                        label: const Text('풀이 보기'),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          textStyle: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompactResultLabel extends StatelessWidget {
  const _CompactResultLabel({required this.isCorrect});

  final bool isCorrect;

  @override
  Widget build(BuildContext context) {
    return Text(
      _compactResultLabel(isCorrect),
      style: TextStyle(
        color: isCorrect ? AppColors.success : AppColors.textSub,
        fontWeight: FontWeight.w700,
        fontSize: 12,
      ),
    );
  }
}

String _compactResultLabel(bool isCorrect) => isCorrect ? '정답' : '오답';

String _resolveChoiceAnswerText(GeneratedProblem problem, String rawAnswer) {
  final trimmed = rawAnswer.trim();
  if (trimmed.isEmpty) return rawAnswer;
  for (final choice in problem.choices) {
    if (choice.id == trimmed) {
      return '${choice.id}. ${choice.label}';
    }
  }
  return rawAnswer;
}

class _ReviewChoiceList extends StatelessWidget {
  const _ReviewChoiceList({
    required this.problem,
    required this.selectedAnswer,
  });

  final GeneratedProblem problem;
  final String selectedAnswer;

  @override
  Widget build(BuildContext context) {
    final selected = selectedAnswer.trim();
    final correct = problem.correctAnswer.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '선택지',
          style: TextStyle(
            color: AppColors.textSub,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        for (final choice in problem.choices) ...[
          _ReviewChoiceTile(
            choice: choice,
            isSelected: selected == choice.id,
            isCorrectChoice: correct == choice.id,
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ],
    );
  }
}

class _ReviewChoiceTile extends StatelessWidget {
  const _ReviewChoiceTile({
    required this.choice,
    required this.isSelected,
    required this.isCorrectChoice,
  });

  final ProblemChoice choice;
  final bool isSelected;
  final bool isCorrectChoice;

  @override
  Widget build(BuildContext context) {
    Color borderColor = AppColors.borderStrong;
    Color background = AppColors.surface;
    Color iconColor = AppColors.textMuted;
    IconData icon = Icons.radio_button_unchecked;

    if (isCorrectChoice) {
      borderColor = AppColors.success.withValues(alpha: 0.45);
      background = AppColors.success.withValues(alpha: 0.08);
      iconColor = AppColors.success;
      icon = Icons.check_circle_outline_rounded;
    } else if (isSelected) {
      borderColor = AppColors.accent.withValues(alpha: 0.4);
      background = AppColors.accent.withValues(alpha: 0.06);
      iconColor = AppColors.accent;
      icon = Icons.radio_button_checked;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: borderColor, width: isSelected || isCorrectChoice ? 1.5 : 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: iconColor),
          const SizedBox(width: 10),
          Expanded(
            child: MixedMathText(
              '${choice.id}. ${choice.label}',
              style: const TextStyle(
                color: AppColors.text,
                height: 1.4,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProblemResult {
  const _ProblemResult({
    required this.index,
    required this.problem,
    required this.attempt,
  });

  final int index;
  final GeneratedProblem problem;
  final ProblemAttempt attempt;
}

class _ProblemReviewCard extends StatelessWidget {
  const _ProblemReviewCard({required this.item});

  final _ProblemResult item;

  @override
  Widget build(BuildContext context) {
    final ok = item.attempt.isCorrect;
    final concept = primaryConceptTag(item.problem.conceptTags);
    final problem = item.problem;
    final userAnswer = _resolveChoiceAnswerText(problem, item.attempt.answer);
    final correctAnswer = problem.isMultipleChoice
        ? _resolveChoiceAnswerText(problem, problem.correctAnswer)
        : problem.correctAnswer;

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            problem.title,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 6),
          _ProblemMetaText(
            difficulty: formatDifficultyLabel(problem.difficulty),
            concept: concept,
          ),
          const SizedBox(height: 12),
          MixedMathText(
            problem.prompt,
            style: const TextStyle(
              color: AppColors.textSub,
              height: 1.45,
              fontSize: 14,
            ),
          ),
          if (problem.isMultipleChoice) ...[
            const SizedBox(height: 14),
            _ReviewChoiceList(
              problem: problem,
              selectedAnswer: item.attempt.answer,
            ),
          ],
          const SizedBox(height: 12),
          _AnswerLine(
            label: '내 답',
            value: userAnswer,
            color: ok ? AppColors.textSub : AppColors.textSub,
          ),
          if (!ok) ...[
            const SizedBox(height: 6),
            _AnswerLine(
              label: '정답',
              value: correctAnswer,
              color: AppColors.success,
            ),
          ],
          if (item.attempt.feedback.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            MixedMathText(
              item.attempt.feedback,
              preserveWhitespace: true,
              style: const TextStyle(
                color: AppColors.textSub,
                height: 1.45,
                fontSize: 13,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ProblemMetaText extends StatelessWidget {
  const _ProblemMetaText({
    required this.difficulty,
    this.concept,
  });

  final String difficulty;
  final String? concept;

  @override
  Widget build(BuildContext context) {
    final parts = <String>[difficulty];
    if (concept != null && concept!.trim().isNotEmpty) {
      parts.add(concept!);
    }
    return Text(
      parts.join(' · '),
      style: const TextStyle(
        color: AppColors.textSub,
        fontSize: 12,
        height: 1.4,
      ),
    );
  }
}

class _AnswerLine extends StatelessWidget {
  const _AnswerLine({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 40,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ),
        Expanded(
          child: MixedMathText(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.text,
            ),
          ),
        ),
      ],
    );
  }
}

/// 틀린/맞힌 개념 태그로 간단 피드백 문장 생성
String? buildPracticeConfusionInsight({
  required List<String> wrongConcepts,
  required List<String> correctConcepts,
}) {
  final wrong = wrongConcepts.toSet().where((s) => s.trim().isNotEmpty).toList();
  final correct =
      correctConcepts.toSet().where((s) => s.trim().isNotEmpty).toList();

  if (wrong.isEmpty && correct.isEmpty) return null;

  final parts = <String>[];
  if (wrong.isNotEmpty) {
    parts.add('${wrong.join('·')} 부분을 다시 확인해 보세요.');
  }
  if (correct.isNotEmpty) {
    parts.add('${correct.join('·')}은(는) 잘 이해하고 있어요.');
  }
  return parts.join('\n');
}
