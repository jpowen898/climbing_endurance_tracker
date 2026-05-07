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
    this.multiLine = false,
    this.includePoint,
  });

  final List<SetWithRoute> sets;
  final double Function(SetWithRoute item) yValue;
  final String label;
  final bool multiLine;
  final bool Function(SetWithRoute item)? includePoint;

  @override
  Widget build(BuildContext context) {
    final filteredSets = includePoint == null
        ? sets
        : sets.where(includePoint!).toList();
    if (filteredSets.isEmpty) return const Center(child: Text('No data yet'));
    final sessionDates = filteredSets.map((s) => s.sessionStartedAt).toSet().toList()..sort();
    final sessionIndex = {for (var i = 0; i < sessionDates.length; i++) sessionDates[i]: i.toDouble()};
    final labelIndices = <int>{};
    if (sessionDates.length <= 4) {
      labelIndices.addAll(List.generate(sessionDates.length, (i) => i));
    } else {
      for (var i = 0; i < 4; i++) {
        labelIndices.add(((i * (sessionDates.length - 1)) / 3).round());
      }
    }

    if (!multiLine) {
      final spots = <FlSpot>[];
      for (final set in filteredSets) {
        spots.add(FlSpot(sessionIndex[set.sessionStartedAt]!, yValue(set)));
      }
      spots.sort((a, b) => a.x.compareTo(b.x));
      if (spots.isEmpty) return const Center(child: Text('No data yet'));
      return Column(
        children: [
          Expanded(
            child: LineChart(
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
                        if (index >= 0 && index < sessionDates.length && labelIndices.contains(index)) {
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
            ),
          ),
        ],
      );
    }

    // Multi-line mode: group by set number
    final bySetNumber = <int, List<SetWithRoute>>{};
    for (final item in filteredSets) {
      bySetNumber.putIfAbsent(item.set.setNumber, () => []).add(item);
    }
    final maxSetNumber = bySetNumber.keys.reduce((a, b) => a > b ? a : b);
    final colors = [
      Theme.of(context).colorScheme.primary,
      Theme.of(context).colorScheme.secondary,
      Theme.of(context).colorScheme.tertiary,
      Colors.red,
      Colors.green,
      Colors.blue,
      Colors.orange,
      Colors.purple,
      Colors.pink,
      Colors.teal,
    ];
    final lineBarsData = <LineChartBarData>[];
    final legendItems = <Widget>[];

    for (var setNum = 1; setNum <= maxSetNumber; setNum++) {
      final setItems = bySetNumber[setNum] ?? [];
      if (setItems.isEmpty) continue;
      final spots = <FlSpot>[];
      for (final item in setItems) {
        spots.add(FlSpot(sessionIndex[item.sessionStartedAt]!, yValue(item)));
      }
      spots.sort((a, b) => a.x.compareTo(b.x));
      final color = colors[(setNum - 1) % colors.length];
      lineBarsData.add(LineChartBarData(
        spots: spots,
        isCurved: true,
        barWidth: 3,
        dotData: const FlDotData(show: true),
        color: color,
      ));
      legendItems.add(Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 12, height: 12, color: color),
          const SizedBox(width: 4),
          Text('Set $setNum'),
        ],
      ));
    }

    if (lineBarsData.isEmpty) return const Center(child: Text('No data yet'));
    return Column(
      children: [
        Expanded(
          child: LineChart(
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
                      if (index >= 0 && index < sessionDates.length && labelIndices.contains(index)) {
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
              lineBarsData: lineBarsData,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 16,
          runSpacing: 4,
          children: legendItems,
        ),
      ],
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
