import 'package:flutter/material.dart';

import '../layout/tablet_layout.dart';
import '../models/app_models.dart';
import '../services/api_client.dart';
import '../widgets/app_card.dart';
import 'practice_screen.dart';

class LoopResultScreen extends StatelessWidget {
  const LoopResultScreen({
    super.key,
    required this.apiClient,
    required this.problemSet,
    required this.feedback,
    this.stats,
  });

  final ApiClient apiClient;
  final GeneratedProblemSet problemSet;
  final Map<String, ProblemAttempt> feedback;
  final LearningStats? stats;

  int get _correctCount =>
      feedback.values.where((attempt) => attempt.isCorrect).length;

  int get _totalCount => problemSet.problems.length;

  bool get _passed => _correctCount == _totalCount;

  List<({int index, GeneratedProblem problem, ProblemAttempt attempt})>
      get _wrongItems {
    final items = <({int index, GeneratedProblem problem, ProblemAttempt attempt})>[];
    for (var i = 0; i < problemSet.problems.length; i++) {
      final problem = problemSet.problems[i];
      final attempt = feedback[problem.id];
      if (attempt != null && !attempt.isCorrect) {
        items.add((index: i + 1, problem: problem, attempt: attempt));
      }
    }
    return items;
  }

  @override
  Widget build(BuildContext context) {
    final wrongItems = _wrongItems;
    final gradient = _passed
        ? const [Color(0xFF064E3B), Color(0xFF065F46)]
        : const [Color(0xFF7F1D1D), Color(0xFF991B1B)];

    return Scaffold(
      appBar: AppBar(title: const Text('훈련 결과')),
      body: SafeArea(
        child: TabletBody(
          child: ListView(
            padding: TabletLayout.pagePadding(context),
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: LinearGradient(
                    colors: gradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      _passed ? '🎉' : '😤',
                      style: const TextStyle(fontSize: 48),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '$_correctCount/$_totalCount 맞았어요!',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _passed
                          ? '완벽해요! 이 개념은 충분히 이해했어요.'
                          : '아직 ${wrongItems.length}개가 틀렸어요.\n조금만 더 하면 완전히 이해할 수 있어요!',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xB3FFFFFF),
                        height: 1.55,
                      ),
                    ),
                  ],
                ),
              ),
              if (wrongItems.isNotEmpty) ...[
                const SizedBox(height: 20),
                const Text(
                  '틀린 문제 원인',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                ),
                const SizedBox(height: 8),
                AppCard(
                  child: Column(
                    children: [
                      for (var i = 0; i < wrongItems.length; i++) ...[
                        if (i > 0)
                          const Divider(height: 20, color: Color(0xFF1E293B)),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('❌', style: TextStyle(fontSize: 18)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '문제 ${wrongItems[i].index}번',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    wrongItems[i].problem.conceptTags.isNotEmpty
                                        ? wrongItems[i].problem.conceptTags.first
                                        : wrongItems[i].attempt.feedback,
                                    style: const TextStyle(
                                      color: Color(0xFF94A3B8),
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (_) => PracticeScreen(
                        apiClient: apiClient,
                        problemSet: problemSet,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('다시 도전하기'),
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
                child: const Text('나중에 하기'),
              ),
              if (stats != null && stats!.accuracyDelta != 0) ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF14532D).withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: const Color(0xFF22C55E).withValues(alpha: 0.25),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '📈 성장 중이에요!',
                        style: TextStyle(
                          color: Color(0xFF86EFAC),
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '이번 주 정답률 ${stats!.accuracy}% '
                        '(${stats!.accuracyDelta >= 0 ? '+' : ''}${stats!.accuracyDelta}%)\n'
                        '포기하지 않으면 반드시 올라요!',
                        style: const TextStyle(
                          color: Color(0xFFCBD5E1),
                          height: 1.5,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
