import 'package:flutter/material.dart';

import '../database.dart';
import '../models.dart';
import '../utils.dart';
import '../widgets/dialogs.dart';

class RawDataPage extends StatefulWidget {
  const RawDataPage({super.key});

  @override
  State<RawDataPage> createState() => _RawDataPageState();
}

class _RawDataPageState extends State<RawDataPage> {
  final db = ClimbDatabase.instance;
  List<RouteEntry> _routes = [];
  List<WorkoutSession> _sessions = [];
  List<SetWithRoute> _sets = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final routes = await db.routes();
    final sessions = await db.sessions();
    final sets = await db.allSets();
    if (!mounted) return;
    setState(() {
      _routes = routes;
      _sessions = sessions;
      _sets = sets;
    });
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Raw Data',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              IconButton(
                tooltip: 'Add route',
                onPressed: _addRoute,
                icon: const Icon(Icons.add),
              )
            ],
          ),
          const SizedBox(height: 12),
          Text('Routes', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          ..._routes.map((route) => Card(
                child: ListTile(
                  title: Text(route.name),
                  subtitle: Text([
                    if (route.wall.isNotEmpty) route.wall,
                    if (route.holdCount != null) '${route.holdCount} holds',
                    if (route.notes.isNotEmpty) route.notes,
                  ].join(' - ')),
                  trailing: IconButton(
                    tooltip: 'Edit route',
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () => _editRoute(route),
                  ),
                ),
              )),
          const SizedBox(height: 18),
          Text('Sessions', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          ..._sessions.map((session) => Card(
                child: ListTile(
                  title: Text(dateFormat.format(session.startedAt)),
                  subtitle: Text(
                    'Target rest ${formatDuration(session.targetRestSeconds)}',
                  ),
                  trailing: IconButton(
                    tooltip: 'Edit session',
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () => _editSession(session),
                  ),
                ),
              )),
          const SizedBox(height: 18),
          Text('Sets', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: const [
                DataColumn(label: Text('Date')),
                DataColumn(label: Text('Route')),
                DataColumn(label: Text('Set')),
                DataColumn(label: Text('Moves')),
                DataColumn(label: Text('Wall')),
                DataColumn(label: Text('Rest')),
                DataColumn(label: Text('')),
              ],
              rows: _sets.map((item) {
                return DataRow(cells: [
                  DataCell(Text(shortDate.format(item.sessionStartedAt))),
                  DataCell(Text(item.routeName)),
                  DataCell(Text('${item.set.setNumber}')),
                  DataCell(Text('${item.set.movesCompleted}')),
                  DataCell(Text(formatDuration(item.set.wallTimeSeconds))),
                  DataCell(Text(item.set.restAfterSeconds == null
                      ? ''
                      : formatDuration(item.set.restAfterSeconds!))),
                  DataCell(IconButton(
                    tooltip: 'Edit set',
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () => _editSet(item.set),
                  )),
                ]);
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addRoute() async {
    final route = await showDialog<RouteEntry>(
      context: context,
      builder: (_) => const RouteDialog(),
    );
    if (route == null) return;
    await db.upsertRoute(route);
    await _load();
  }

  Future<void> _editRoute(RouteEntry route) async {
    final edited = await showDialog<RouteEntry>(
      context: context,
      builder: (_) => RouteDialog(route: route),
    );
    if (edited == null) return;
    await db.upsertRoute(edited);
    await _load();
  }

  Future<void> _editSession(WorkoutSession session) async {
    final edited = await showDialog<WorkoutSession>(
      context: context,
      builder: (_) => SessionDialog(session: session),
    );
    if (edited == null) return;
    await db.updateSession(edited);
    await _load();
  }

  Future<void> _editSet(WorkoutSet set) async {
    final edited = await showDialog<WorkoutSet>(
      context: context,
      builder: (_) => EditSetDialog(set: set, routes: _routes),
    );
    if (edited == null) return;
    await db.updateSet(edited);
    await _load();
  }
}
