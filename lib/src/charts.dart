import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'models.dart';
import 'utils.dart';

class ChartCard extends StatelessWidget {
  const ChartCard({super.key, required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            SizedBox(height: 240, child: child),
          ],
        ),
      ),
    );
  }
}

FlTitlesData compactTitles(String yLabel) => FlTitlesData(
      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      bottomTitles: const AxisTitles(
        sideTitles: SideTitles(showTitles: true, reservedSize: 28),
      ),
      leftTitles: AxisTitles(
        axisNameWidget: Text(yLabel),
        sideTitles: const SideTitles(showTitles: true, reservedSize: 42),
      ),
    );

class TrendChart extends StatelessWidget {
  const TrendChart({
    super.key,
    required this.sets,
    required this.yValue,
    required this.label,
  });

  final List<SetWithRoute> sets;
  final double Function(SetWithRoute item) yValue;
  final String label;

  @override
  Widget build(BuildContext context) {
    if (sets.isEmpty) return const Center(child: Text('No data yet'));
    final sessionDates = sets.map((s) => s.sessionStartedAt).toSet().toList()..sort();
    final sessionIndex = {for (var i = 0; i < sessionDates.length; i++) sessionDates[i]: i.toDouble()};
    final spots = <FlSpot>[];
    for (final set in sets) {
      spots.add(FlSpot(sessionIndex[set.sessionStartedAt]!, yValue(set)));
    }
    spots.sort((a, b) => a.x.compareTo(b.x));
    return LineChart(
      LineChartData(
        minY: 0,
        gridData: const FlGridData(show: true),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 60,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index >= 0 && index < sessionDates.length) {
                  return Text(shortDate.format(sessionDates[index]), style: const TextStyle(fontSize: 10));
                }
                return const Text('');
              },
            ),
          ),
          leftTitles: AxisTitles(
            axisNameWidget: Text(label),
            sideTitles: const SideTitles(showTitles: true, reservedSize: 42),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            barWidth: 3,
            dotData: const FlDotData(show: true),
            color: Theme.of(context).colorScheme.primary,
          ),
        ],
      ),
    );
  }
}

class FalloffChart extends StatelessWidget {
  const FalloffChart({super.key, required this.sets});

  final List<SetWithRoute> sets;

  @override
  Widget build(BuildContext context) {
    final grouped = <int, List<SetWithRoute>>{};
    for (final item in sets) {
      grouped.putIfAbsent(item.set.sessionId, () => []).add(item);
    }
    final spots = <FlSpot>[];
    var x = 0;
    for (final group in grouped.values) {
      group.sort((a, b) => a.set.setNumber.compareTo(b.set.setNumber));
      if (group.isEmpty || group.first.set.movesCompleted == 0) continue;
      final first = group.first.set.movesCompleted;
      for (final item in group) {
        final falloff = (first - item.set.movesCompleted) / first * 100;
        spots.add(FlSpot(x.toDouble(), falloff));
        x++;
      }
    }
    if (spots.isEmpty) return const Center(child: Text('No falloff data yet'));
    return LineChart(LineChartData(
      gridData: const FlGridData(show: true),
      titlesData: compactTitles('%'),
      borderData: FlBorderData(show: false),
      lineBarsData: [
        LineChartBarData(
          spots: spots,
          isCurved: false,
          barWidth: 3,
          color: Theme.of(context).colorScheme.secondary,
        ),
      ],
    ));
  }
}

class RestFalloffChart extends StatelessWidget {
  const RestFalloffChart({super.key, required this.sets});

  final List<SetWithRoute> sets;

  @override
  Widget build(BuildContext context) {
    final bySession = <int, List<SetWithRoute>>{};
    for (final item in sets) {
      bySession.putIfAbsent(item.set.sessionId, () => []).add(item);
    }
    final spots = <FlSpot>[];
    for (final group in bySession.values) {
      group.sort((a, b) => a.set.setNumber.compareTo(b.set.setNumber));
      for (var i = 1; i < group.length; i++) {
        final prev = group[i - 1].set;
        final current = group[i].set;
        if (prev.movesCompleted == 0 || prev.restAfterSeconds == null) continue;
        final falloff = (prev.movesCompleted - current.movesCompleted) /
            prev.movesCompleted *
            100;
        spots.add(FlSpot(prev.restAfterSeconds!.toDouble() / 60, falloff));
      }
    }
    if (spots.isEmpty) return const Center(child: Text('No rest data yet'));
    return ScatterChart(ScatterChartData(
      gridData: const FlGridData(show: true),
      titlesData: compactTitles('%'),
      borderData: FlBorderData(show: false),
      scatterSpots: spots
          .map((spot) => ScatterSpot(
                spot.x,
                spot.y,
                dotPainter: FlDotCirclePainter(
                  radius: 5,
                  color: Theme.of(context).colorScheme.tertiary,
                ),
              ))
          .toList(),
    ));
  }
}
