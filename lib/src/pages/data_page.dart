import 'package:flutter/material.dart';

import '../database.dart';
import '../models.dart';
import '../charts.dart';
import '../utils.dart';

class DataPage extends StatefulWidget {
  const DataPage({super.key});

  @override
  State<DataPage> createState() => _DataPageState();
}

class _DataPageState extends State<DataPage> {
  final db = ClimbDatabase.instance;
  List<Exercise> _exercises = [];
  List<SetWithExercise> _sets = [];
  List<WorkoutSession> _sessions = [];
  final Map<int, List<HeartRateSample>> _heartRateSamples = {};
  int? _exerciseId;
  DateTimeRange _dateRange = DateTimeRange(
    start: DateTime.now().subtract(const Duration(days: 30)),
    end: DateTime.now(),
  );

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final exercises = await db.exercises();
    final sessions = await db.sessions();
    final sets = await db.allSets();
    final heartRateSamples = <int, List<HeartRateSample>>{};
    for (final session in sessions) {
      if (session.id != null) {
        final samples = await db.heartRateSamplesForSession(session.id!);
        if (samples.isNotEmpty) {
          heartRateSamples[session.id!] = samples;
        }
      }
    }
    if (!mounted) return;
    setState(() {
      _exercises = exercises;
      _sessions = sessions;
      _sets = sets.reversed.toList();
      _heartRateSamples
        ..clear()
        ..addAll(heartRateSamples);
    });
  }

  List<WorkoutSession> get _filteredSessions {
    return _sessions.where((session) {
      return session.startedAt
              .isAfter(_dateRange.start.subtract(const Duration(days: 1))) &&
          session.startedAt
              .isBefore(_dateRange.end.add(const Duration(days: 1)));
    }).toList();
  }

  List<SetWithExercise> get _filteredSets {
    return _sets.where((item) {
      final inRange = item.sessionStartedAt
              .isAfter(_dateRange.start.subtract(const Duration(days: 1))) &&
          item.sessionStartedAt
              .isBefore(_dateRange.end.add(const Duration(days: 1)));
      final exerciseMatches =
          _exerciseId == null || item.set.exerciseId == _exerciseId;
      return inRange && exerciseMatches;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredSets;
    final sessionDates = _filteredSessions
        .map((s) =>
            DateTime(s.startedAt.year, s.startedAt.month, s.startedAt.day))
        .toSet()
        .toList()
      ..sort();
    final setsBySession = <int, List<SetWithExercise>>{};
    for (final item in _sets) {
      setsBySession.putIfAbsent(item.set.sessionId, () => []).add(item);
    }
    final selectedExercise = _exerciseId == null
        ? null
        : firstWhereOrNull(
            _exercises, (exercise) => exercise.id == _exerciseId);
    final metricKeys = selectedExercise == null
        ? filtered.expand((item) => item.exercise.plotMetrics).toSet().toList()
        : selectedExercise.plotMetrics;
    final metrics =
        metricKeys.map(metricDefinition).whereType<MetricDefinition>().toList();

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Data',
            style: Theme.of(context)
                .textTheme
                .headlineMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          _TimeFilter(
            dateRange: _dateRange,
            onChanged: (range) => setState(() => _dateRange = range),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int?>(
            initialValue: _exerciseId,
            decoration: const InputDecoration(labelText: 'Exercise filter'),
            items: [
              const DropdownMenuItem(value: null, child: Text('All exercises')),
              ..._exercises.map((exercise) => DropdownMenuItem(
                  value: exercise.id, child: Text(exercise.name))),
            ],
            onChanged: (value) => setState(() => _exerciseId = value),
          ),
          const SizedBox(height: 16),
          if (metrics.isEmpty)
            const Card(
                child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('No plot data yet')))
          else
            ...metrics.expand((metric) sync* {
              final metricSets = filtered
                  .where((item) => metric.value(item.set) != null)
                  .toList();
              if (metricSets.isEmpty) return;
              yield ChartCard(
                title: '${metric.label} over time',
                child: TrendChart(
                    sets: metricSets,
                    sessionDates: sessionDates,
                    metric: metric),
              );
              yield const SizedBox(height: 12);
            }),
          ..._filteredSessions.expand((session) sync* {
            final sessionId = session.id;
            if (sessionId == null) return;
            final samples =
                _heartRateSamples[sessionId] ?? const <HeartRateSample>[];
            if (samples.isEmpty) return;
            yield ChartCard(
              title:
                  'Heart rate - ${session.name} ${shortDate.format(session.startedAt)}',
              child: HeartRateWorkoutChart(
                samples: samples,
                sets: setsBySession[sessionId] ?? const <SetWithExercise>[],
                sessionStart: session.startedAt,
              ),
            );
            yield const SizedBox(height: 12);
          }),
          if (selectedExercise != null &&
              selectedExercise.plotMetrics.isNotEmpty) ...[
            const SizedBox(height: 4),
            ChartCard(
              title: 'Falloff from first set',
              child: FalloffChart(
                sets: filtered,
                metric: metricDefinition(selectedExercise.plotMetrics.first) ??
                    metricDefinitions.first,
              ),
            ),
            const SizedBox(height: 12),
            ChartCard(
              title: 'Falloff vs rest',
              child: RestFalloffChart(
                sets: filtered,
                metric: metricDefinition(selectedExercise.plotMetrics.first) ??
                    metricDefinitions.first,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TimeFilter extends StatelessWidget {
  const _TimeFilter({required this.dateRange, required this.onChanged});

  final DateTimeRange dateRange;
  final ValueChanged<DateTimeRange> onChanged;

  Future<void> _pickRange(BuildContext context) async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: dateRange,
    );
    if (picked != null) onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Time range', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            OutlinedButton(
              onPressed: () => onChanged(DateTimeRange(
                  start: DateTime.now().subtract(const Duration(days: 30)),
                  end: DateTime.now())),
              child: const Text('1 month'),
            ),
            OutlinedButton(
              onPressed: () => onChanged(DateTimeRange(
                  start: DateTime.now().subtract(const Duration(days: 63)),
                  end: DateTime.now())),
              child: const Text('9 weeks'),
            ),
            OutlinedButton(
              onPressed: () => onChanged(DateTimeRange(
                  start: DateTime.now().subtract(const Duration(days: 180)),
                  end: DateTime.now())),
              child: const Text('6 months'),
            ),
            OutlinedButton(
              onPressed: () => onChanged(DateTimeRange(
                  start: DateTime.now().subtract(const Duration(days: 365)),
                  end: DateTime.now())),
              child: const Text('1 year'),
            ),
            OutlinedButton(
                onPressed: () => _pickRange(context),
                child: const Text('Custom')),
          ],
        ),
        const SizedBox(height: 4),
        Text(
            '${shortDate.format(dateRange.start)} - ${shortDate.format(dateRange.end)}',
            style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
