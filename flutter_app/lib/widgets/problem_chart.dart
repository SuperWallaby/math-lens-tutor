import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class ProblemChart extends StatelessWidget {
  const ProblemChart({super.key, required this.chart});

  final Map<String, dynamic> chart;

  @override
  Widget build(BuildContext context) {
    final type = chart['type'] as String? ?? 'bar';
    final values = _extractValues(chart);

    if (values.isEmpty) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: 180,
      child: type == 'line' || type == 'scatter'
          ? LineChart(
              LineChartData(
                gridData: const FlGridData(show: true),
                borderData: FlBorderData(show: false),
                titlesData: const FlTitlesData(
                  rightTitles: AxisTitles(),
                  topTitles: AxisTitles(),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: [
                      for (var i = 0; i < values.length; i++)
                        FlSpot(i.toDouble(), values[i]),
                    ],
                    isCurved: true,
                    color: const Color(0xFF2563EB),
                    barWidth: 3,
                    dotData: const FlDotData(show: true),
                  ),
                ],
              ),
            )
          : BarChart(
              BarChartData(
                gridData: const FlGridData(show: true),
                borderData: FlBorderData(show: false),
                titlesData: const FlTitlesData(
                  rightTitles: AxisTitles(),
                  topTitles: AxisTitles(),
                ),
                barGroups: [
                  for (var i = 0; i < values.length; i++)
                    BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: values[i],
                          color: const Color(0xFF2563EB),
                          width: 18,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ],
                    ),
                ],
              ),
            ),
    );
  }

  List<double> _extractValues(Map<String, dynamic> chart) {
    final data = chart['data'];
    if (data is! Map) {
      return const [];
    }
    final datasets = data['datasets'];
    if (datasets is! List || datasets.isEmpty || datasets.first is! Map) {
      return const [];
    }
    final values = (datasets.first as Map)['data'];
    if (values is! List) {
      return const [];
    }

    return values
        .whereType<num>()
        .map((value) => value.toDouble())
        .toList(growable: false);
  }
}
