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
  List<RouteEntry> _routes = [];
  List<SetWithRoute> _sets = [];
  int? _routeId;
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
    final routes = await db.routes();
    final sets = await db.allSets();
    if (!mounted) return;
    setState(() {
      _routes = routes;
      _sets = sets.reversed.toList();
      _routeId ??= routes.isEmpty ? null : routes.first.id;
    });
  }

  List<SetWithRoute> get _filteredSets {
    return _sets.where((item) {
      return item.sessionStartedAt.isAfter(_dateRange.start.subtract(const Duration(days: 1))) &&
             item.sessionStartedAt.isBefore(_dateRange.end.add(const Duration(days: 1)));
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _routeId == null
        ? _filteredSets
        : _filteredSets.where((item) => item.set.routeId == _routeId).toList();
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Data',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 12),
          _TimeFilter(
            dateRange: _dateRange,
            onChanged: (range) => setState(() => _dateRange = range),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int?>(
            initialValue: _routeId,
            decoration: const InputDecoration(labelText: 'Route filter'),
            items: [
              const DropdownMenuItem(value: null, child: Text('All routes')),
              ..._routes.map((r) => DropdownMenuItem(value: r.id, child: Text(r.name))),
            ],
            onChanged: (value) => setState(() => _routeId = value),
          ),
          const SizedBox(height: 16),
          ChartCard(
            title: 'Moves over time',
            child: TrendChart(
              sets: filtered,
              yValue: (item) => item.set.movesCompleted.toDouble(),
              label: 'moves',
              multiLine: true,
            ),
          ),
          const SizedBox(height: 12),
          ChartCard(
            title: 'Speed over time',
            child: TrendChart(
              sets: filtered,
              yValue: (item) => item.set.movesPerMinute,
              label: 'moves/min',
              multiLine: true,
              includePoint: (item) => item.set.wallTimeSeconds > 0,
            ),
          ),
          const SizedBox(height: 12),
          ChartCard(
            title: 'Wall time over time',
            child: TrendChart(
              sets: filtered,
              yValue: (item) => item.set.wallTimeSeconds.toDouble(),
              label: 'seconds',
              multiLine: true,
              includePoint: (item) => item.set.wallTimeSeconds > 0,
            ),
          ),
          const SizedBox(height: 12),
          ChartCard(
            title: 'Rest time over time',
            child: TrendChart(
              sets: filtered,
              yValue: (item) => item.set.restAfterSeconds?.toDouble() ?? 0,
              label: 'seconds',
              multiLine: true,
              includePoint: (item) => item.set.restAfterSeconds != null && item.set.restAfterSeconds! > 0,
            ),
          ),
          const SizedBox(height: 12),
          ChartCard(
            title: 'Falloff from first set',
            child: FalloffChart(sets: filtered),
          ),
          const SizedBox(height: 12),
          ChartCard(
            title: 'Falloff vs rest',
            child: RestFalloffChart(sets: filtered),
          ),
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
                end: DateTime.now(),
              )),
              child: const Text('1 month'),
            ),
            OutlinedButton(
              onPressed: () => onChanged(DateTimeRange(
                start: DateTime.now().subtract(const Duration(days: 63)),
                end: DateTime.now(),
              )),
              child: const Text('9 weeks'),
            ),
            OutlinedButton(
              onPressed: () => onChanged(DateTimeRange(
                start: DateTime.now().subtract(const Duration(days: 180)),
                end: DateTime.now(),
              )),
              child: const Text('6 months'),
            ),
            OutlinedButton(
              onPressed: () => onChanged(DateTimeRange(
                start: DateTime.now().subtract(const Duration(days: 365)),
                end: DateTime.now(),
              )),
              child: const Text('1 year'),
            ),
            OutlinedButton(
              onPressed: () => _pickRange(context),
              child: const Text('Custom'),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '${shortDate.format(dateRange.start)} - ${shortDate.format(dateRange.end)}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}
