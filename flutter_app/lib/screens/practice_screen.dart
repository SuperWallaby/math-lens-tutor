import 'package:flutter/material.dart';

import '../layout/tablet_layout.dart';
import '../models/app_models.dart';
import '../services/api_client.dart';
import '../utils/problem_set_pdf.dart';
import '../widgets/app_card.dart';
import '../widgets/problem_chart.dart';
import '../widgets/problem_jsx_graph.dart';
import '../widgets/mixed_math_text.dart';
import 'dashboard_screen.dart';

import 'loop_result_screen.dart';

class PracticeScreen extends StatefulWidget {
  const PracticeScreen({
    super.key,
    required this.apiClient,
    required this.problemSet,
  });

  final ApiClient apiClient;
  final GeneratedProblemSet problemSet;

  @override
  State<PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends State<PracticeScreen> {
  final Map<String, String> _answers = {};
  final Map<String, ProblemAttempt> _feedback = {};
  String? _submittingProblemId;
  String? _error;
  int _currentIndex = 0;

  Future<void> _exportPdf() async {
    try {
      await openSimilarProblemsPdf(widget.problemSet);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('PDF를 만들지 못했습니다: $e')),
      );
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
        setId: widget.problemSet.id,
        problemId: problem.id,
        answer: answer,
      );
      setState(() => _feedback[problem.id] = attempt);
      if (_isSetComplete) {
        await _openLoopResult();
      } else if (mounted && _currentIndex < widget.problemSet.problems.length - 1) {
        setState(() => _currentIndex += 1);
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
    if (widget.problemSet.problems.isEmpty) return false;
    for (final problem in widget.problemSet.problems) {
      if (!_feedback.containsKey(problem.id)) return false;
    }
    return true;
  }

  Future<void> _openLoopResult() async {
    LearningStats? stats;
    try {
      final profile = await widget.apiClient.getLearningProfile();
      stats = profile.stats;
    } catch (_) {}

    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LoopResultScreen(
          apiClient: widget.apiClient,
          problemSet: widget.problemSet,
          feedback: Map.unmodifiable(_feedback),
          stats: stats,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final problems = widget.problemSet.problems;
    final total = problems.length;
    final current = total == 0 ? null : problems[_currentIndex.clamp(0, total - 1)];
    final progress = total == 0 ? 0.0 : (_currentIndex + 1) / total;

    return Scaffold(
      appBar: AppBar(
        title: const Text('유사 문제 훈련'),
        actions: [
          if (total > 0)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E3A8A),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${_currentIndex + 1} / $total',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                      color: Color(0xFF93C5FD),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: TabletBody(
          child: ListView(
            padding: TabletLayout.pagePadding(context),
            children: [
              MixedMathText(
                widget.problemSet.title,
                style: TextStyle(
                  fontSize: TabletLayout.isWideTablet(context) ? 24 : 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              MixedMathText(
                widget.problemSet.learningGoal,
                style: TextStyle(
                  color: const Color(0xFFCBD5E1),
                  height: 1.5,
                  fontSize: TabletLayout.bodySmall(context),
                ),
              ),
              if (total > 0) ...[
                const SizedBox(height: 14),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 8,
                    backgroundColor: const Color(0xFF1E293B),
                    color: const Color(0xFF2563EB),
                  ),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: Color(0xFFFCA5A5))),
              ],
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _exportPdf,
                icon: const Icon(Icons.picture_as_pdf_outlined),
                label: const Text('유사문제 PDF로 받기'),
              ),
              if (current != null) ...[
                const SizedBox(height: 16),
                _ProblemCard(
                  index: _currentIndex,
                  problem: current,
                  answer: _answers[current.id],
                  feedback: _feedback[current.id],
                  submitting: _submittingProblemId == current.id,
                  onAnswerChanged: (value) {
                    setState(() => _answers[current.id] = value);
                  },
                  onSubmit: () => _submit(current),
                ),
                if (_currentIndex > 0)
                  OutlinedButton(
                    onPressed: () => setState(() => _currentIndex -= 1),
                    child: const Text('이전 문제'),
                  ),
                if (_feedback.containsKey(current.id) &&
                    _currentIndex < total - 1)
                  FilledButton(
                    onPressed: () => setState(() => _currentIndex += 1),
                    child: const Text('다음 문제'),
                  ),
              ],
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _isSetComplete ? _openLoopResult : null,
                icon: const Icon(Icons.flag_rounded),
                label: const Text('세트 결과 보기'),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => DashboardScreen(apiClient: widget.apiClient),
                    ),
                  );
                },
                icon: const Icon(Icons.insights_rounded),
                label: const Text('대시보드 보기'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProblemCard extends StatelessWidget {
  const _ProblemCard({
    required this.index,
    required this.problem,
    required this.answer,
    required this.feedback,
    required this.submitting,
    required this.onAnswerChanged,
    required this.onSubmit,
  });

  final int index;
  final GeneratedProblem problem;
  final String? answer;
  final ProblemAttempt? feedback;
  final bool submitting;
  final ValueChanged<String> onAnswerChanged;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Pill('문제 ${index + 1}'),
              _Pill(problem.difficulty),
              for (final tag in problem.conceptTags) _Pill(tag),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            problem.title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          MixedMathText(
            problem.prompt,
            style: const TextStyle(color: Color(0xFFCBD5E1), height: 1.55),
          ),
          if (problem.chart != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
              ),
              child: ProblemChart(chart: problem.chart!),
            ),
          ],
          if (jsxDiagramShows(problem.jsxGraph)) ...[
            const SizedBox(height: 14),
            if ((problem.jsxGraph!['captionKo'] as String?)
                    ?.trim()
                    .isNotEmpty ??
                false)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  problem.jsxGraph!['captionKo'] as String,
                  style: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 13,
                  ),
                ),
              ),
            ProblemJsxGraph(spec: problem.jsxGraph!),
          ],
          const SizedBox(height: 16),
          if (problem.isMultipleChoice)
            for (final choice in problem.choices)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => onAnswerChanged(choice.id),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: answer == choice.id
                          ? const Color(0xFF1D4ED8)
                          : const Color(0xFF020617),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: answer == choice.id
                            ? const Color(0xFF60A5FA)
                            : Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          answer == choice.id
                              ? Icons.radio_button_checked
                              : Icons.radio_button_unchecked,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: MixedMathText(
                            '${choice.id}. ${choice.label}',
                            style: const TextStyle(
                              color: Colors.white,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
          else
            TextField(
              minLines: 3,
              maxLines: 6,
              onChanged: onAnswerChanged,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: '풀이 또는 답안을 직접 작성하세요.',
                border: OutlineInputBorder(),
              ),
            ),
          const SizedBox(height: 10),
          FilledButton(
            onPressed: submitting ? null : onSubmit,
            child: Text(submitting ? '채점 중...' : '답안 제출'),
          ),
          if (feedback != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: feedback!.isCorrect
                    ? const Color(0xFF14532D)
                    : const Color(0xFF7F1D1D),
                borderRadius: BorderRadius.circular(16),
              ),
              child: MixedMathText(
                feedback!.feedback,
                paragraphSoftBreak: true,
                style: const TextStyle(
                  color: Colors.white,
                  height: 1.45,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label, style: const TextStyle(fontSize: 12)),
    );
  }
}
