import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../layout/tablet_layout.dart';
import '../models/app_models.dart';
import '../services/api_client.dart';
import '../utils/choice_label_format.dart';
import '../utils/problem_answer_format.dart';
import '../utils/problem_set_pdf.dart';
import '../widgets/app_card.dart';
import '../widgets/bouncing_ellipsis_text.dart';
import '../widgets/problem_answer_input.dart';
import '../widgets/question_view.dart';
import '../widgets/visualization_view.dart';
import '../widgets/mixed_math_text.dart';
import 'dashboard_screen.dart';

import 'loop_result_screen.dart';
import '../theme/app_design_system.dart';

class PracticeScreen extends StatefulWidget {
  const PracticeScreen({
    super.key,
    required this.apiClient,
    required this.problemSet,
    this.demoInitialIndex = 0,
    this.demoFeedback,
    this.demoAnswers,
    this.reviewMode = false,
    this.liteMode = false,
  });

  final ApiClient apiClient;
  final GeneratedProblemSet problemSet;
  final int demoInitialIndex;
  final Map<String, ProblemAttempt>? demoFeedback;
  final Map<String, String>? demoAnswers;
  final bool reviewMode;
  final bool liteMode;

  @override
  State<PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends State<PracticeScreen> {
  final Map<String, String> _answers = {};
  final Map<String, ProblemAttempt> _feedback = {};
  String? _submittingProblemId;
  String? _error;
  late int _currentIndex;
  late GeneratedProblemSet _problemSet;
  bool _menuLoading = false;
  int _slideDirection = 1;

  @override
  void initState() {
    super.initState();
    _problemSet = widget.problemSet;
    _currentIndex = widget.demoInitialIndex;
    if (widget.demoAnswers != null) {
      _answers.addAll(widget.demoAnswers!);
    }
    if (widget.demoFeedback != null) {
      _feedback.addAll(widget.demoFeedback!);
    }
  }

  Future<void> _exportPdf() async {
    try {
      await openSimilarProblemsPdf(context, _problemSet);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('PDF를 만들지 못했습니다: $e')),
      );
    }
  }

  Future<void> _loadNewProblemSet({required bool harder}) async {
    if (_menuLoading || widget.reviewMode) return;

    final hasProgress = _feedback.isNotEmpty || _answers.isNotEmpty;
    if (hasProgress) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(harder ? '더 어려운 문제로 바꿀까요?' : '새로운 문제를 받을까요?'),
          content: Text(
            harder
                ? '지금까지 푼 기록은 유지되지만, 새 문제 세트로 이동합니다.'
                : '아직 풀지 않은 문제는 새 세트로 대체됩니다.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('계속'),
            ),
          ],
        ),
      );
      if (ok != true || !mounted) return;
    }

    setState(() => _menuLoading = true);
    try {
      final newSet = await widget.apiClient.retryPractice(
        submissionId: _problemSet.submissionId,
        previousSetId: _problemSet.id,
        harder: harder,
      );
      if (!mounted) return;
      setState(() {
        _problemSet = newSet;
        _currentIndex = 0;
        _answers.clear();
        _feedback.clear();
        _error = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            harder ? '더 어려운 문제 세트를 불러왔어요.' : '새로운 문제 5개를 불러왔어요.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) setState(() => _menuLoading = false);
    }
  }

  Future<void> _replaceCurrentProblem({required bool harder}) async {
    if (_menuLoading || widget.reviewMode) return;
    final current = _problemSet.problems.isEmpty
        ? null
        : _problemSet.problems[_currentIndex.clamp(0, _problemSet.problems.length - 1)];
    if (current == null) return;

    if (_feedback.containsKey(current.id)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이미 제출한 문제는 교체할 수 없어요.')),
      );
      return;
    }

    setState(() => _menuLoading = true);
    try {
      final updated = await widget.apiClient.refreshPracticeProblem(
        setId: _problemSet.id,
        problemId: current.id,
        harder: harder,
      );
      if (!mounted) return;
      setState(() {
        _problemSet = updated;
        _answers.remove(current.id);
        _feedback.remove(current.id);
        _error = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            harder ? '더 어려운 문제로 바꿨어요.' : '새 문제로 바꿨어요.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) setState(() => _menuLoading = false);
    }
  }

  void _onMenuAction(String action) {
    switch (action) {
      case 'new_set':
        _loadNewProblemSet(harder: false);
        break;
      case 'harder_problem':
        _replaceCurrentProblem(harder: true);
        break;
      case 'save_pdf':
        _exportPdf();
        break;
    }
  }

  Future<void> _submit(GeneratedProblem problem) async {
    final answer = _answers[problem.id];
    if (answer == null || answer.trim().isEmpty) {
      setState(() => _error = '답안을 먼저 입력해 주세요.');
      return;
    }

    setState(() {
      _submittingProblemId = problem.id;
      _error = null;
    });

    try {
      final attempt = await widget.apiClient.submitAnswer(
        setId: _problemSet.id,
        problemId: problem.id,
        answer: answer,
      );
      setState(() => _feedback[problem.id] = attempt);
      if (attempt.relearnedConcepts.isNotEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '재학습 성공됨 · ${attempt.relearnedConcepts.join(", ")}',
            ),
          ),
        );
      }
      if (_isSetComplete) {
        await _openLoopResult();
      }
    } catch (error) {
      setState(() => _error = error.toString());
    } finally {
      if (mounted) {
        setState(() => _submittingProblemId = null);
      }
    }
  }

  bool get _isSetComplete {
    if (_problemSet.problems.isEmpty) return false;
    for (final problem in _problemSet.problems) {
      if (!_feedback.containsKey(problem.id)) return false;
    }
    return true;
  }

  Future<void> _openLoopResult() async {
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LoopResultScreen(
          apiClient: widget.apiClient,
          problemSet: _problemSet,
          feedback: Map.unmodifiable(_feedback),
        ),
      ),
    );
  }

  void _goToProblem(int index) {
    final next = index.clamp(0, _problemSet.problems.length - 1);
    if (next == _currentIndex) return;
    setState(() {
      _slideDirection = next > _currentIndex ? 1 : -1;
      _currentIndex = next;
    });
  }

  Widget _problemTransitionBuilder(Widget child, Animation<double> animation) {
    final slide = Tween<Offset>(
      begin: Offset(0.14 * _slideDirection, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));

    return FadeTransition(
      opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
      child: SlideTransition(position: slide, child: child),
    );
  }

  @override
  Widget build(BuildContext context) {
    final problems = _problemSet.problems;
    final total = problems.length;
    final current = total == 0 ? null : problems[_currentIndex.clamp(0, total - 1)];
    final progress = total == 0 ? 0.0 : (_currentIndex + 1) / total;
    final currentFeedback = current == null ? null : _feedback[current.id];
    final hasSubmittedCurrent = currentFeedback != null;

    final showSubmitBar =
        !widget.reviewMode && current != null && !hasSubmittedCurrent;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.text,
        iconTheme: const IconThemeData(color: AppColors.text),
        actionsIconTheme: const IconThemeData(color: AppColors.text),
        title: Text(
          '유사 문제 훈련',
          style: Theme.of(context).appBarTheme.titleTextStyle?.copyWith(
                color: AppColors.text,
              ),
        ),
        actionsPadding: const EdgeInsets.only(right: 12),
        actions: widget.reviewMode
            ? null
            : [
                if (_menuLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  )
                else if (widget.liteMode)
                  IconButton(
                    onPressed: _exportPdf,
                    icon: const Icon(Icons.picture_as_pdf_outlined),
                    tooltip: 'PDF로 저장',
                  )
                else ...[
                  PopupMenuButton<String>(
                    tooltip: '문제 메뉴',
                    icon: const Icon(Icons.more_vert_rounded),
                    onSelected: _onMenuAction,
                    itemBuilder: (context) => const [
                      PopupMenuItem(
                        value: 'new_set',
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.refresh_rounded, size: 20),
                          title: Text('새로운 문제받기'),
                          subtitle: Text(
                            '같은 유형 문제 5개 새로',
                            style: TextStyle(fontSize: 11),
                          ),
                          isThreeLine: true,
                        ),
                      ),
                      PopupMenuItem(
                        value: 'harder_problem',
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.trending_up_rounded, size: 20),
                          title: Text('더 어려운 문제로 교체'),
                          subtitle: Text(
                            '지금 보는 문제만 상향',
                            style: TextStyle(fontSize: 11),
                          ),
                          isThreeLine: true,
                        ),
                      ),
                      PopupMenuDivider(),
                      PopupMenuItem(
                        value: 'save_pdf',
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.picture_as_pdf_outlined, size: 20),
                          title: Text('저장하기'),
                          subtitle: Text(
                            'PDF로 저장·공유',
                            style: TextStyle(fontSize: 11),
                          ),
                          isThreeLine: true,
                        ),
                      ),
                    ],
                  ),
                const SizedBox(width: 4),
                IconButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            DashboardScreen(apiClient: widget.apiClient),
                      ),
                    );
                  },
                  icon: const Icon(Icons.insights_outlined),
                  tooltip: '대시보드',
                  visualDensity: VisualDensity.standard,
                ),
                ],
              ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: TabletBody(
                child: ListView(
                  padding: TabletLayout.pagePadding(context),
                  children: [
                    MixedMathText(
                      _problemSet.title,
                      style: TextStyle(
                        color: AppColors.text,
                        fontSize: TabletLayout.isWideTablet(context) ? 22 : 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    MixedMathText(
                      _problemSet.learningGoal,
                      style: TextStyle(
                        color: AppColors.textSub,
                        height: 1.55,
                        letterSpacing: 0.1,
                        fontWeight: FontWeight.w500,
                        fontSize: TabletLayout.bodySmall(context),
                      ),
                    ),
                    if (total > 0) ...[
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(99),
                              child: LinearProgressIndicator(
                                value: progress,
                                minHeight: 7,
                                backgroundColor: AppColors.surfaceMuted,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            '${_currentIndex + 1}/$total',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (_error != null) ...[
                      const SizedBox(height: 10),
                      Text(_error!, style: const TextStyle(color: AppColors.accent)),
                    ],
                    if (current != null) ...[
                      const SizedBox(height: 14),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 260),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        transitionBuilder: _problemTransitionBuilder,
                        child: _ProblemCard(
                          key: ValueKey<String>(current.id),
                          index: _currentIndex,
                          total: total,
                          problem: current,
                          answer: _answers[current.id],
                          feedback: currentFeedback,
                          submitting: _submittingProblemId == current.id,
                          showInlineSubmit: !showSubmitBar,
                          onAnswerChanged: (value) {
                            setState(() => _answers[current.id] = value);
                          },
                          onSubmit: () => _submit(current),
                          onNext: _currentIndex < total - 1
                              ? () => _goToProblem(_currentIndex + 1)
                              : null,
                        ),
                      ),
                      if (_currentIndex > 0) ...[
                        const SizedBox(height: 24),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton(
                            onPressed: () => _goToProblem(_currentIndex - 1),
                            child: const Text('← 이전 문제'),
                          ),
                        ),
                      ],
                    ],
                    if (!widget.reviewMode && _isSetComplete) ...[
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: _openLoopResult,
                        icon: const Icon(Icons.flag_rounded),
                        label: const Text('세트 결과 보기'),
                      ),
                    ],
                    if (showSubmitBar) const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
            if (showSubmitBar)
              _PracticeSubmitBar(
                submitting: _submittingProblemId == current.id,
                onSubmit: () => _submit(current),
              ),
          ],
        ),
      ),
    );
  }
}

class _PracticeSubmitBar extends StatelessWidget {
  const _PracticeSubmitBar({
    required this.submitting,
    required this.onSubmit,
  });

  final bool submitting;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        TabletLayout.pagePadding(context).left,
        AppSpacing.md,
        TabletLayout.pagePadding(context).right,
        AppSpacing.lg,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: submitting ? null : onSubmit,
          style: FilledButton.styleFrom(
            minimumSize:
                const Size.fromHeight(AppSizes.buttonHeightKeyAction),
          ),
          child: _SubmitButtonLabel(submitting: submitting),
        ),
      ),
    );
  }
}

class _ProblemCard extends StatelessWidget {
  const _ProblemCard({
    super.key,
    required this.index,
    required this.total,
    required this.problem,
    required this.answer,
    required this.feedback,
    required this.submitting,
    required this.showInlineSubmit,
    required this.onAnswerChanged,
    required this.onSubmit,
    required this.onNext,
  });

  final int index;
  final int total;
  final GeneratedProblem problem;
  final String? answer;
  final ProblemAttempt? feedback;
  final bool submitting;
  final bool showInlineSubmit;
  final ValueChanged<String> onAnswerChanged;
  final VoidCallback onSubmit;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final answerFormat = resolveAnswerFormat(problem);
    final concept = primaryConceptTag(problem.conceptTags);
    final submitted = feedback != null;

    return AppCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            [
              formatDifficultyLabel(problem.difficulty),
              ?concept,
            ].join(' · '),
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 12,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            problem.title,
            style: const TextStyle(
              color: AppColors.text,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          QuestionView(problem: problem),
          if (submitted) ...[
            const SizedBox(height: 12),
            QuestionView(
              problem: problem,
              showPrompt: false,
              showSolution: true,
            ),
          ],
          if (submitted) ...[
            const SizedBox(height: 20),
            _SubmittedBanner(
              feedback: feedback!,
              correctAnswer: problem.correctAnswer,
            ),
            if (onNext != null) ...[
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onNext,
                  icon: const Icon(Icons.arrow_forward_rounded),
                  label: const Text('다음 문제'),
                  style: FilledButton.styleFrom(
                    minimumSize:
                        const Size.fromHeight(AppSizes.buttonHeightKeyAction),
                  ),
                ),
              ),
            ] else if (index + 1 >= total) ...[
              const SizedBox(height: 16),
              Text(
                '마지막 문제입니다. 아래에서 세트 결과를 확인하세요.',
                style: TextStyle(
                  color: AppColors.textSub,
                  fontSize: TabletLayout.bodySmall(context),
                ),
              ),
            ],
          ] else ...[
            const SizedBox(height: 16),
            if (answerFormat == ProblemAnswerFormat.multipleChoice)
              for (final choice in problem.choices)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(AppRadii.md),
                    onTap: () => onAnswerChanged(choice.id),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: answer == choice.id
                            ? AppColors.primary.withValues(alpha: 0.12)
                            : AppColors.surface,
                        borderRadius: BorderRadius.circular(AppRadii.md),
                        border: Border.all(
                          color: answer == choice.id
                              ? AppColors.primary
                              : AppColors.borderStrong,
                          width: answer == choice.id ? 2 : 1.5,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            answer == choice.id
                                ? Icons.radio_button_checked
                                : Icons.radio_button_unchecked,
                            size: 22,
                            color: answer == choice.id
                                ? AppColors.primary
                                : AppColors.textMuted,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: MixedMathText(
                              formatChoiceDisplayLabel(choice.id, choice.label),
                              style: const TextStyle(
                                color: AppColors.text,
                                height: 1.4,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
            else
              ProblemAnswerInput(
                format: answerFormat,
                value: answer,
                enabled: !submitting,
                onChanged: onAnswerChanged,
              ),
            if (showInlineSubmit) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: submitting ? null : onSubmit,
                  style: FilledButton.styleFrom(
                    minimumSize:
                        const Size.fromHeight(AppSizes.buttonHeightKeyAction),
                  ),
                  child: _SubmitButtonLabel(submitting: submitting),
                ),
              ),
            ] else
              const SizedBox(height: 4),
          ],
          if (kDebugMode) ...[
            const SizedBox(height: 10),
            Text(
              describeProblemRender(
              problem,
              hasJsx: visualizationShows(
                visualizationData: problem.visualizationData,
                chart: problem.chart,
                jsxGraph: problem.jsxGraph,
              ),
            ),
              style: const TextStyle(
                fontSize: 10,
                color: AppColors.textMuted,
                fontFamily: 'monospace',
                height: 1.3,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SubmitButtonLabel extends StatefulWidget {
  const _SubmitButtonLabel({required this.submitting});

  final bool submitting;

  @override
  State<_SubmitButtonLabel> createState() => _SubmitButtonLabelState();
}

class _SubmitButtonLabelState extends State<_SubmitButtonLabel>
    with SingleTickerProviderStateMixin {
  static const _labelStyle = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w700,
  );

  AnimationController? _dotsController;

  @override
  void initState() {
    super.initState();
    if (widget.submitting) {
      _startDotsAnimation();
    }
  }

  @override
  void didUpdateWidget(covariant _SubmitButtonLabel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.submitting && !oldWidget.submitting) {
      _startDotsAnimation();
    } else if (!widget.submitting && oldWidget.submitting) {
      _stopDotsAnimation();
    }
  }

  @override
  void dispose() {
    _stopDotsAnimation();
    super.dispose();
  }

  void _startDotsAnimation() {
    _dotsController ??= AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  void _stopDotsAnimation() {
    _dotsController?.dispose();
    _dotsController = null;
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.submitting) {
      return const Text('답안 제출', style: _labelStyle);
    }

    _startDotsAnimation();

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        BouncingEllipsisInline(
          prefix: '채점 중',
          controller: _dotsController!,
          style: _labelStyle,
        ),
      ],
    );
  }
}

class _SubmittedBanner extends StatelessWidget {
  const _SubmittedBanner({
    required this.feedback,
    required this.correctAnswer,
  });

  final ProblemAttempt feedback;
  final String correctAnswer;

  @override
  Widget build(BuildContext context) {
    final ok = feedback.isCorrect;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: ok
                ? AppColors.success.withValues(alpha: 0.12)
                : AppColors.accent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(AppRadii.md),
            border: Border.all(
              color: ok
                  ? AppColors.success.withValues(alpha: 0.35)
                  : AppColors.accent.withValues(alpha: 0.35),
            ),
          ),
          child: Row(
            children: [
              Icon(
                ok ? Icons.check_circle_rounded : Icons.cancel_rounded,
                color: ok ? AppColors.success : AppColors.accent,
                size: 22,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ok
                    ? const Text(
                        '정답',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      )
                    : Row(
                        children: [
                          const Text(
                            '오답 · 정답: ',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                              color: AppColors.text,
                            ),
                          ),
                          Expanded(
                            child: MixedMathText(
                              correctAnswer,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                                color: AppColors.text,
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),
        if (feedback.feedback.trim().isNotEmpty) ...[
          const SizedBox(height: 16),
          MixedMathText(
            feedback.feedback,
            preserveWhitespace: true,
            style: const TextStyle(
              color: AppColors.textSub,
              height: 1.45,
              fontSize: 14,
            ),
          ),
        ],
      ],
    );
  }
}
