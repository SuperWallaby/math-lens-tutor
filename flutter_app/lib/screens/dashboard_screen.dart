import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../models/app_models.dart';
import '../services/api_client.dart';
import '../widgets/app_card.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key, required this.apiClient});

  final ApiClient apiClient;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late final Future<LearningInsight> _future = widget.apiClient.getInsight();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('학습 대시보드')),
      body: SafeArea(
        child: FutureBuilder<LearningInsight>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text(snapshot.error.toString()));
            }

            final insight = snapshot.data!;
            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const Text(
                  '사용자 수준 피드백',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _MetricCard(title: '현재 수준', value: insight.levelLabel),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _MetricCard(
                        title: '정답률',
                        value: '${insight.accuracy}%',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _MetricCard(
                  title: '숙련도 점수',
                  value: '${insight.masteryScore}',
                  fullWidth: true,
                ),
                const SizedBox(height: 16),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('최근 풀이 결과', style: _titleStyle),
                      const SizedBox(height: 14),
                      SizedBox(
                        height: 180,
                        child: BarChart(
                          BarChartData(
                            borderData: FlBorderData(show: false),
                            gridData: const FlGridData(show: true),
                            titlesData: const FlTitlesData(
                              rightTitles: AxisTitles(),
                              topTitles: AxisTitles(),
                            ),
                            barGroups: [
                              BarChartGroupData(
                                x: 0,
                                barRods: [
                                  BarChartRodData(
                                    toY: insight.accuracy.toDouble(),
                                    color: const Color(0xFF22C55E),
                                    width: 24,
                                  ),
                                ],
                              ),
                              BarChartGroupData(
                                x: 1,
                                barRods: [
                                  BarChartRodData(
                                    toY: (100 - insight.accuracy).toDouble(),
                                    color: const Color(0xFFEF4444),
                                    width: 24,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('약점 개념', style: _titleStyle),
                      const SizedBox(height: 12),
                      for (final item in insight.weakConcepts)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(item.concept),
                          trailing: Text('오답 ${item.misses}'),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('다음 학습 피드백', style: _titleStyle),
                      const SizedBox(height: 12),
                      for (final feedback in insight.recentFeedback)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Text(
                            '• $feedback',
                            style: const TextStyle(
                              color: Color(0xFFCBD5E1),
                              height: 1.5,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.value,
    this.fullWidth = false,
  });

  final String title;
  final String value;
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Color(0xFF94A3B8))),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: fullWidth ? 30 : 22,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

const _titleStyle = TextStyle(fontSize: 18, fontWeight: FontWeight.w900);
