import 'package:flutter/material.dart';
import 'package:csv/csv.dart';

import '../database.dart';
import '../models.dart';
import '../utils.dart';
import '../widgets/dialogs.dart';
import '../widgets/session_set_table.dart';

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

  Future<void> _importCsv() async {
    final csvController = TextEditingController();
    final imported = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Import CSV'),
        content: TextField(
          controller: csvController,
          maxLines: 10,
          decoration: const InputDecoration(
            hintText: 'Paste CSV data here',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Import'),
          ),
        ],
      ),
    );
    if (imported != true) return;
    try {
      final csvData = const CsvToListConverter(eol: '\n').convert(csvController.text);
      if (csvData.isEmpty) return;
      final header = csvData[0].map((e) => e.toString()).toList();
      if (header.length < 5 || !header[0].toLowerCase().contains('date')) {
        throw 'Invalid CSV format';
      }
      var importedSessions = 0;
      for (final row in csvData.skip(1)) {
        if (row.length < 5) continue;
        final dateStr = row[0].toString();
        final routeName = row[2].toString();
        final dateParts = dateStr.split('/');
        if (dateParts.length != 3) continue;
        final month = int.parse(dateParts[0]);
        final day = int.parse(dateParts[1]);
        final year = 2000 + int.parse(dateParts[2]);
        final sessionDate = DateTime(year, month, day);
        final routeId = await db.getOrCreateRoute(routeName);
        final session = WorkoutSession(
          startedAt: sessionDate,
          targetRestSeconds: 480, // 8 min default
        );
        final sessionId = await db.createSession(session);
        var setNumber = 1;
        for (var i = 4; i < row.length; i++) {
          final valueStr = row[i].toString().trim();
          if (valueStr.isEmpty) continue;
          final value = double.tryParse(valueStr);
          if (value == null) continue;
          final wallTimeSeconds = 0;
          final set = WorkoutSet(
            sessionId: sessionId,
            routeId: routeId,
            setNumber: setNumber,
            startedAt: sessionDate,
            endedAt: sessionDate,
            wallTimeSeconds: wallTimeSeconds,
            restAfterSeconds: null,
            targetRestSeconds: 480,
            movesCompleted: value.toInt(),
          );
          await db.insertSet(set);
          setNumber++;
        }
        importedSessions++;
      }
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Imported $importedSessions sessions successfully')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Import failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final setsBySession = <int, List<WorkoutSet>>{};
    for (final item in _sets) {
      setsBySession.putIfAbsent(item.set.sessionId, () => []).add(item.set);
    }

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
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Routes', style: Theme.of(context).textTheme.titleLarge),
              FilledButton.icon(
                onPressed: _addRoute,
                icon: const Icon(Icons.add),
                label: const Text('Add route'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ExpansionTile(
            title: Text('${_routes.length} routes'),
            initiallyExpanded: false,
            children: _routes.map((route) => Card(
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
                )).toList(),
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Workouts', style: Theme.of(context).textTheme.titleLarge),
              Row(
                children: [
                  FilledButton.icon(
                    onPressed: _addSession,
                    icon: const Icon(Icons.add),
                    label: const Text('Add session'),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: _importCsv,
                    icon: const Icon(Icons.upload),
                    label: const Text('Import CSV'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          ..._sessions.map((session) {
            final sessionSets = setsBySession[session.id] ?? [];
            final totalDuration = sessionSets.fold<int>(0, (sum, set) {
              return sum + set.wallTimeSeconds + (set.restAfterSeconds ?? 0);
            });
            return Card(
              child: ExpansionTile(
                key: ValueKey(session.id),
                title: Text(dateFormat.format(session.startedAt)),
                subtitle: Text(
                  '${sessionSets.length} sets · ${formatDuration(totalDuration)}',
                ),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                children: [
                  SessionSetTable(
                    sets: sessionSets,
                    routes: _routes,
                    onChanged: (set) => _updateSet(set),
                    onDelete: _deleteSet,
                    onAdd: () => _addSet(session.id!),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton.icon(
                        onPressed: () => _editSession(session),
                        icon: const Icon(Icons.edit_outlined),
                        label: const Text('Edit session'),
                      ),
                      const SizedBox(width: 8),
                      TextButton.icon(
                        onPressed: () => _deleteSession(session),
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Delete session'),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
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


  Future<void> _addSession() async {
    final session = await showDialog<WorkoutSession>(
      context: context,
      builder: (_) => const NewSessionDialog(),
    );
    if (session == null) return;
    await db.createSession(session);
    await _load();
  }

  Future<void> _deleteSession(WorkoutSession session) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete session'),
        content: const Text('Remove this workout and all of its sets?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirm != true || session.id == null) return;
    await db.deleteSession(session.id!);
    await _load();
  }

  Future<void> _updateSet(WorkoutSet set) async {
    await db.updateSet(set);
    await _load();
  }

  Future<void> _addSet(int sessionId) async {
    if (_routes.isEmpty) return;
    final sessionSets = _sets.where((item) => item.set.sessionId == sessionId).toList();
    final routeId = _routes.first.id!;
    final newSet = WorkoutSet(
      sessionId: sessionId,
      routeId: routeId,
      setNumber: sessionSets.length + 1,
      startedAt: DateTime.now(),
      endedAt: DateTime.now(),
      wallTimeSeconds: 0,
      restAfterSeconds: null,
      targetRestSeconds: 0,
      movesCompleted: 0,
    );
    await db.insertSet(newSet);
    await _renumberSets(sessionId);
    await _load();
  }

  Future<void> _deleteSet(int setId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete set'),
        content: const Text('Remove this set from the workout?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirm != true) return;
    final sets = _sets.where((item) => item.set.id == setId).toList();
    if (sets.isEmpty) return;
    final sessionId = sets.first.set.sessionId;
    await db.deleteSet(setId);
    await _renumberSets(sessionId);
    await _load();
  }

  Future<void> _renumberSets(int sessionId) async {
    final sets = await db.setsForSession(sessionId);
    for (var i = 0; i < sets.length; i++) {
      final desired = i + 1;
      if (sets[i].setNumber != desired) {
        await db.updateSet(sets[i].copyWith(setNumber: desired));
      }
    }
  }
}
