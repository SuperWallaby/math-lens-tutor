import 'package:flutter/material.dart';

import '../models/app_models.dart';
import '../services/api_client.dart';
import '../widgets/app_card.dart';
import 'practice_screen.dart';

class AnalysisScreen extends StatelessWidget {
  const AnalysisScreen({
    super.key,
    required this.apiClient,
    required this.result,
  });

  final ApiClient apiClient;
  final AnalyzeResult result;

  @override
  Widget build(BuildContext context) {
    final analysis = result.submission.analysis;

    return Scaffold(
      appBar: AppBar(title: const Text('AI 풀이 분석')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                TagChip(
                  analysis.isLikelyCorrect ? '정답 가능성 높음' : '오답 가능성 높음',
                  color: analysis.isLikelyCorrect
                      ? const Color(0xFF16A34A)
                      : const Color(0xFFDC2626),
                ),
                TagChip('신뢰도 ${(analysis.confidence * 100).round()}%'),
              ],
            ),
            const SizedBox(height: 16),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('추출한 문제', style: _titleStyle),
                  const SizedBox(height: 10),
                  Text(analysis.problemText, style: _bodyStyle),
                  const Divider(height: 30),
                  Row(
                    children: [
                      Expanded(
                        child: _AnswerBox(
                          title: '학생 답안',
                          value: analysis.extractedStudentAnswer,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _AnswerBox(
                          title: '추정 정답',
                          value: analysis.inferredCorrectAnswer,
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
                  const Text('풀이 과정에서 보이는 문제', style: _titleStyle),
                  const SizedBox(height: 12),
                  for (final step in analysis.solutionSteps)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Text('• $step', style: _bodyStyle),
                    ),
                  const SizedBox(height: 8),
                  Text(
                    analysis.errorSummary,
                    style: const TextStyle(color: Color(0xFFFCA5A5), height: 1.5),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('부족 개념', style: _titleStyle),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final concept in analysis.weakConcepts) TagChip(concept),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text('추천 훈련', style: _titleStyle),
                  const SizedBox(height: 10),
                  for (final focus in analysis.recommendedFocus)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text('• $focus', style: _bodyStyle),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => PracticeScreen(
                      apiClient: apiClient,
                      problemSet: result.problemSet,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.quiz_rounded),
              label: const Text('유사 문제 5개 풀기'),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnswerBox extends StatelessWidget {
  const _AnswerBox({required this.title, required this.value});

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF020617),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

const _titleStyle = TextStyle(fontSize: 17, fontWeight: FontWeight.w900);
const _bodyStyle = TextStyle(color: Color(0xFFCBD5E1), height: 1.55);
