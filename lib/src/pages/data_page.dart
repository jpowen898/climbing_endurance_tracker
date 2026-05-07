import 'package:flutter/material.dart';

import '../database.dart';
import '../models.dart';
import '../charts.dart';

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

  @override
  Widget build(BuildContext context) {
    final filtered = _routeId == null
        ? _sets
        : _sets.where((item) => item.set.routeId == _routeId).toList();
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
            ),
          ),
          const SizedBox(height: 12),
          ChartCard(
            title: 'Speed over time',
            child: TrendChart(
              sets: filtered,
              yValue: (item) => item.set.movesPerMinute,
              label: 'moves/min',
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
