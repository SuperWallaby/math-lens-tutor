import 'package:flutter/material.dart';

import '../layout/tablet_layout.dart';
import '../models/app_models.dart';
import '../services/api_client.dart';
import '../widgets/app_card.dart';
import '../widgets/mixed_math_text.dart';
import 'practice_screen.dart';

/// `src/lib/types.ts` 과 동일 문자열이어야 레거시 응답과 맞물림
const String _weakConceptPlaceholderLegacy = '사진만으로는 부족한 개념을 특정하기 어렵습니다.';
const String _recommendedFocusPlaceholderLegacy =
    '우선 동일 유형 문제를 조금 더 풀며 풀이 과정을 적는 연습을 권합니다.';

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
    final titleStyle = TextStyle(
      fontSize: TabletLayout.isWideTablet(context) ? 20 : 17,
      fontWeight: FontWeight.w900,
    );
    final bodyStyle = TextStyle(
      color: const Color(0xFFCBD5E1),
      height: 1.55,
      fontSize: TabletLayout.body(context),
    );

    final weakShown = _meaningfulWeakConcepts(analysis.weakConcepts);
    final focusShown = _meaningfulRecommendedFocus(analysis.recommendedFocus);
    final showTrainingSection = weakShown.isNotEmpty || focusShown.isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('AI 풀이 분석')),
      body: SafeArea(
        child: TabletBody(
          child: ListView(
            padding: TabletLayout.pagePadding(context),
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
                    Text('추출한 문제', style: titleStyle),
                    const SizedBox(height: 10),
                    MixedMathText(analysis.problemText, style: bodyStyle),
                    const Divider(height: 30),
                    Row(
                      children: [
                        Expanded(
                          child: _AnswerBox(
                            title: '학생 답안',
                            value: analysis.extractedStudentAnswer,
                            wide: TabletLayout.isWideTablet(context),
                            valueBold: true,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _AnswerBox(
                            title: '추정 정답',
                            value: analysis.inferredCorrectAnswer,
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
                    Text('풀이과정', style: titleStyle),
                    const SizedBox(height: 12),
                    for (final step in analysis.solutionSteps)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('• ', style: bodyStyle),
                            Expanded(
                              child: MixedMathText(step, style: bodyStyle),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 8),
                    MixedMathText(
                      analysis.errorSummary,
                      style: TextStyle(
                        color: const Color(0xFFFCA5A5),
                        height: 1.5,
                        fontSize: TabletLayout.body(context),
                      ),
                    ),
                  ],
                ),
              ),
              if (showTrainingSection) ...[
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
              ],
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
  final String value;
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
          MixedMathText(
            value,
            style: TextStyle(
              color: Colors.white,
              fontWeight: valueBold ? FontWeight.w800 : FontWeight.w600,
              fontSize: wide ? 18 : 16,
            ),
          ),
        ],
      ),
    );
  }
}
