import 'package:flutter/material.dart';

import '../models/app_models.dart';
import '../theme/app_design_system.dart';
import 'mixed_math_text.dart';
import 'visualization_view.dart';

/// 문제 본문 + 수식 + 시각화 (재사용)
class QuestionView extends StatelessWidget {
  const QuestionView({
    super.key,
    required this.problem,
    this.showPrompt = true,
    this.showSolution = false,
    this.promptStyle = const TextStyle(
      color: AppColors.textSub,
      height: 1.45,
      fontSize: 15,
    ),
    this.explanationStyle = const TextStyle(
      color: AppColors.text,
      height: 1.5,
      fontSize: 14,
    ),
  });

  final GeneratedProblem problem;
  final bool showPrompt;
  final bool showSolution;
  final TextStyle promptStyle;
  final TextStyle explanationStyle;

  @override
  Widget build(BuildContext context) {
    final hasPromptViz = visualizationShows(
      visualizationData: problem.visualizationData,
      chart: problem.chart,
      jsxGraph: problem.jsxGraph,
    );
    final hasSolutionViz = visualizationShows(
      visualizationData: problem.solutionVisualizationData,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showPrompt) ...[
          MixedMathText(
            problem.prompt,
            style: promptStyle,
          ),
          if (hasPromptViz) ...[
            const SizedBox(height: 12),
            VisualizationView(
              visualizationData: problem.visualizationData,
              chart: problem.chart,
              jsxGraph: problem.jsxGraph,
            ),
          ],
        ],
        if (showSolution && problem.explanation.trim().isNotEmpty) ...[
          if (showPrompt) const SizedBox(height: 16),
          const Text(
            '풀이',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 13,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 8),
          MixedMathText(
            problem.explanation,
            readableSolutionStep: true,
            style: explanationStyle,
          ),
          if (hasSolutionViz) ...[
            const SizedBox(height: 12),
            VisualizationView(
              visualizationData: problem.solutionVisualizationData,
            ),
          ],
        ],
      ],
    );
  }
}
