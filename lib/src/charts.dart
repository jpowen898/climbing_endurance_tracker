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
          sideTitles: SideTitles(showTitles: true, reservedSize: 28)),
      leftTitles: AxisTitles(
        axisNameWidget: Text(yLabel),
        sideTitles: const SideTitles(showTitles: true, reservedSize: 42),
      ),
    );

class TrendChart extends StatelessWidget {
  const TrendChart({
    super.key,
    required this.sets,
    required this.sessionDates,
    required this.metric,
    this.multiLine = true,
  });

  final List<SetWithExercise> sets;
  final List<DateTime> sessionDates;
  final MetricDefinition metric;
  final bool multiLine;

  @override
  Widget build(BuildContext context) {
    final points =
        sets.where((item) => metric.value(item.set) != null).toList();
    if (points.isEmpty || sessionDates.isEmpty) {
      return const Center(child: Text('No data yet'));
    }
    final minDate = sessionDates.reduce((a, b) => a.isBefore(b) ? a : b);
    final maxDate = sessionDates.reduce((a, b) => a.isAfter(b) ? a : b);
    final totalDays = maxDate.difference(minDate).inDays.toDouble();
    final labelIndices = <int>{};
    if (sessionDates.length <= 4) {
      labelIndices.addAll(List.generate(sessionDates.length, (i) => i));
    } else {
      for (var i = 0; i < 4; i++) {
        labelIndices.add(((i * (sessionDates.length - 1)) / 3).round());
      }
    }

    if (!multiLine) {
      final spots = points.map((item) {
        final days =
            item.sessionStartedAt.difference(minDate).inDays.toDouble();
        return FlSpot(days, metric.value(item.set)!);
      }).toList()
        ..sort((a, b) => a.x.compareTo(b.x));
      return _LineChartBody(
        minDate: minDate,
        sessionDates: sessionDates,
        labelIndices: labelIndices,
        totalDays: totalDays,
        yLabel: metric.unit,
        bars: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            barWidth: 3,
            dotData: const FlDotData(show: true),
            color: Theme.of(context).colorScheme.primary,
          ),
        ],
      );
    }

    final bySetNumber = <int, List<SetWithExercise>>{};
    for (final item in points) {
      bySetNumber.putIfAbsent(item.set.setNumber, () => []).add(item);
    }
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
    final bars = <LineChartBarData>[];
    final legend = <Widget>[];
    final orderedSetNumbers = bySetNumber.keys.toList()..sort();
    for (final setNumber in orderedSetNumbers) {
      final setItems = bySetNumber[setNumber]!;
      final spots = setItems.map((item) {
        final days =
            item.sessionStartedAt.difference(minDate).inDays.toDouble();
        return FlSpot(days, metric.value(item.set)!);
      }).toList()
        ..sort((a, b) => a.x.compareTo(b.x));
      final color = colors[(setNumber - 1).abs() % colors.length];
      bars.add(LineChartBarData(
        spots: spots,
        isCurved: true,
        barWidth: 3,
        dotData: const FlDotData(show: true),
        color: color,
      ));
      legend.add(Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 12, height: 12, color: color),
          const SizedBox(width: 4),
          Text('Set $setNumber'),
        ],
      ));
    }

    return Column(
      children: [
        Expanded(
          child: _LineChartBody(
            minDate: minDate,
            sessionDates: sessionDates,
            labelIndices: labelIndices,
            totalDays: totalDays,
            yLabel: metric.unit,
            bars: bars,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(spacing: 16, runSpacing: 4, children: legend),
      ],
    );
  }
}

class _LineChartBody extends StatelessWidget {
  const _LineChartBody({
    required this.minDate,
    required this.sessionDates,
    required this.labelIndices,
    required this.totalDays,
    required this.yLabel,
    required this.bars,
  });

  final DateTime minDate;
  final List<DateTime> sessionDates;
  final Set<int> labelIndices;
  final double totalDays;
  final String yLabel;
  final List<LineChartBarData> bars;

  @override
  Widget build(BuildContext context) {
    return LineChart(
      LineChartData(
        minX: 0,
        maxX: totalDays == 0 ? 1 : totalDays,
        minY: 0,
        gridData: const FlGridData(show: true),
        titlesData: FlTitlesData(
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 60,
              getTitlesWidget: (value, meta) {
                final days = value.round();
                final date = minDate.add(Duration(days: days));
                final index = sessionDates.indexWhere((d) =>
                    d.year == date.year &&
                    d.month == date.month &&
                    d.day == date.day);
                if (index >= 0 && labelIndices.contains(index)) {
                  return Text(shortDate.format(date),
                      style: const TextStyle(fontSize: 10));
                }
                return const Text('');
              },
            ),
          ),
          leftTitles: AxisTitles(
            axisNameWidget: Text(yLabel),
            sideTitles: const SideTitles(showTitles: true, reservedSize: 42),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: bars,
      ),
    );
  }
}

class FalloffChart extends StatelessWidget {
  const FalloffChart({super.key, required this.sets, required this.metric});

  final List<SetWithExercise> sets;
  final MetricDefinition metric;

  @override
  Widget build(BuildContext context) {
    final grouped = <int, List<SetWithExercise>>{};
    for (final item in sets) {
      grouped.putIfAbsent(item.set.sessionId, () => []).add(item);
    }
    final spots = <FlSpot>[];
    var x = 0;
    for (final group in grouped.values) {
      group.sort((a, b) => a.set.setNumber.compareTo(b.set.setNumber));
      final firstValue = group.isEmpty ? null : metric.value(group.first.set);
      if (firstValue == null || firstValue == 0) continue;
      for (final item in group) {
        final value = metric.value(item.set);
        if (value == null) continue;
        final falloff = (firstValue - value) / firstValue * 100;
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
  const RestFalloffChart({super.key, required this.sets, required this.metric});

  final List<SetWithExercise> sets;
  final MetricDefinition metric;

  @override
  Widget build(BuildContext context) {
    final bySession = <int, List<SetWithExercise>>{};
    for (final item in sets) {
      bySession.putIfAbsent(item.set.sessionId, () => []).add(item);
    }
    final spots = <FlSpot>[];
    for (final group in bySession.values) {
      group.sort((a, b) => a.set.setNumber.compareTo(b.set.setNumber));
      for (var i = 1; i < group.length; i++) {
        final prev = group[i - 1].set;
        final current = group[i].set;
        final previousValue = metric.value(prev);
        final currentValue = metric.value(current);
        if (previousValue == null ||
            previousValue == 0 ||
            currentValue == null ||
            prev.restAfterSeconds == null) {
          continue;
        }
        final falloff = (previousValue - currentValue) / previousValue * 100;
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
                    radius: 5, color: Theme.of(context).colorScheme.tertiary),
              ))
          .toList(),
    ));
  }
}
