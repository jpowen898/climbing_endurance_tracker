import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../database.dart';
import '../models.dart';
import '../utils.dart';
import '../widgets/dialogs.dart';

class RecordPage extends StatefulWidget {
  const RecordPage({super.key});

  @override
  State<RecordPage> createState() => _RecordPageState();
}

enum RecordingMode { idle, climbing, resting }

class _RecordPageState extends State<RecordPage> {
  final db = ClimbDatabase.instance;
  Timer? _ticker;
  List<RouteEntry> _routes = [];
  List<WorkoutSet> _sets = [];
  RecordingMode _mode = RecordingMode.idle;
  int? _sessionId;
  int? _currentRouteId;
  int _targetRestSeconds = 180;
  DateTime? _phaseStartedAt;
  DateTime? _lastRestStartedAt;
  int? _lastSetId;

  @override
  void initState() {
    super.initState();
    _loadRoutes();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _mode != RecordingMode.idle) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _loadRoutes() async {
    final routes = await db.routes();
    if (!mounted) return;
    setState(() => _routes = routes);
  }

  Future<void> _startWorkout() async {
    await _loadRoutes();
    if (!mounted) return;
    final setup = await showDialog<WorkoutSetupResult>(
      context: context,
      builder: (_) => WorkoutSetupDialog(routes: _routes),
    );
    if (setup == null) return;
    final routeId = setup.routeId ??
        await db.upsertRoute(RouteEntry(
          name: setup.newRouteName!,
          createdAt: DateTime.now(),
        ));
    await _loadRoutes();
    final sessionId = await db.createSession(WorkoutSession(
      startedAt: DateTime.now(),
      targetRestSeconds: setup.targetRestSeconds,
    ));
    setState(() {
      _sessionId = sessionId;
      _currentRouteId = routeId;
      _targetRestSeconds = setup.targetRestSeconds;
      _sets = [];
      _mode = RecordingMode.climbing;
      _phaseStartedAt = DateTime.now();
      _lastRestStartedAt = null;
      _lastSetId = null;
    });
  }

  Future<void> _finishClimb() async {
    final sessionId = _sessionId;
    final routeId = _currentRouteId;
    final startedAt = _phaseStartedAt;
    if (sessionId == null || routeId == null || startedAt == null) return;

    final elapsed = math.max(1, DateTime.now().difference(startedAt).inSeconds);
    final entry = await showDialog<SetEntryResult>(
      context: context,
      barrierDismissible: false,
      builder: (_) => SetEntryDialog(
        routes: _routes,
        currentRouteId: routeId,
        elapsedSeconds: elapsed,
      ),
    );
    if (entry == null) return;
    final nextRouteId = entry.nextRouteId ??
        await db.upsertRoute(RouteEntry(
          name: entry.newRouteName!,
          createdAt: DateTime.now(),
        ));
    await _loadRoutes();
    final now = DateTime.now();
    final set = WorkoutSet(
      sessionId: sessionId,
      routeId: routeId,
      setNumber: _sets.length + 1,
      startedAt: startedAt,
      endedAt: now,
      wallTimeSeconds: elapsed,
      restAfterSeconds: null,
      targetRestSeconds: _targetRestSeconds,
      movesCompleted: entry.movesCompleted,
      notes: entry.notes,
    );
    final setId = await db.insertSet(set);
    final updated = await db.setsForSession(sessionId);
    setState(() {
      _sets = updated;
      _currentRouteId = nextRouteId;
      _mode = RecordingMode.resting;
      _phaseStartedAt = now;
      _lastRestStartedAt = now;
      _lastSetId = setId;
    });
  }

  Future<void> _startNextSet() async {
    final restStartedAt = _lastRestStartedAt;
    final lastSetId = _lastSetId;
    var sets = _sets;
    if (restStartedAt != null && lastSetId != null) {
      await db.updateRestAfter(
        lastSetId,
        DateTime.now().difference(restStartedAt).inSeconds,
      );
      if (_sessionId != null) {
        sets = await db.setsForSession(_sessionId!);
      }
    }
    setState(() {
      _sets = sets;
      _mode = RecordingMode.climbing;
      _phaseStartedAt = DateTime.now();
      _lastRestStartedAt = null;
      _lastSetId = null;
    });
  }

  Future<void> _endWorkout() async {
    final id = _sessionId;
    if (id == null) return;
    if (_mode == RecordingMode.resting &&
        _lastRestStartedAt != null &&
        _lastSetId != null) {
      await db.updateRestAfter(
        _lastSetId!,
        DateTime.now().difference(_lastRestStartedAt!).inSeconds,
      );
    }
    await db.endSession(id);
    setState(() {
      _mode = RecordingMode.idle;
      _sessionId = null;
      _currentRouteId = null;
      _sets = [];
      _phaseStartedAt = null;
      _lastRestStartedAt = null;
      _lastSetId = null;
    });
  }

  int get _elapsedSeconds => _phaseStartedAt == null
      ? 0
      : DateTime.now().difference(_phaseStartedAt!).inSeconds;

  int get _restRemaining => _targetRestSeconds - _elapsedSeconds;

  @override
  Widget build(BuildContext context) {
    final route = firstWhereOrNull(_routes, (r) => r.id == _currentRouteId);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Climb Endurance',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
            IconButton(
              tooltip: 'Add route',
              onPressed: _addRoute,
              icon: const Icon(Icons.add_location_alt_outlined),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_mode == RecordingMode.idle)
          _IdlePanel(onStart: _startWorkout, routeCount: _routes.length)
        else
          _ActivePanel(
            mode: _mode,
            routeName: route?.name ?? 'Route',
            elapsedSeconds: _elapsedSeconds,
            restRemainingSeconds: _restRemaining,
            targetRestSeconds: _targetRestSeconds,
            onRest: _finishClimb,
            onStart: _startNextSet,
            onEndWorkout: _endWorkout,
          ),
        const SizedBox(height: 16),
        if (_mode == RecordingMode.resting || _sets.isNotEmpty)
          _WorkoutSetTable(
            sets: _sets,
            routes: _routes,
            onEdit: _editSet,
          ),
      ],
    );
  }

  Future<void> _addRoute() async {
    final route = await showDialog<RouteEntry>(
      context: context,
      builder: (_) => const RouteDialog(),
    );
    if (route == null) return;
    await db.upsertRoute(route);
    await _loadRoutes();
  }

  Future<void> _editSet(WorkoutSet set) async {
    final edited = await showDialog<WorkoutSet>(
      context: context,
      builder: (_) => EditSetDialog(set: set, routes: _routes),
    );
    if (edited == null) return;
    await db.updateSet(edited);
    if (_sessionId != null) {
      final sets = await db.setsForSession(_sessionId!);
      setState(() => _sets = sets);
    }
  }
}

class _IdlePanel extends StatelessWidget {
  const _IdlePanel({required this.onStart, required this.routeCount});

  final VoidCallback onStart;
  final int routeCount;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ready to record',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text('$routeCount saved routes'),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onStart,
              icon: const Icon(Icons.play_arrow),
              label: const Text('Start workout'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivePanel extends StatelessWidget {
  const _ActivePanel({
    required this.mode,
    required this.routeName,
    required this.elapsedSeconds,
    required this.restRemainingSeconds,
    required this.targetRestSeconds,
    required this.onRest,
    required this.onStart,
    required this.onEndWorkout,
  });

  final RecordingMode mode;
  final String routeName;
  final int elapsedSeconds;
  final int restRemainingSeconds;
  final int targetRestSeconds;
  final VoidCallback onRest;
  final VoidCallback onStart;
  final VoidCallback onEndWorkout;

  @override
  Widget build(BuildContext context) {
    final climbing = mode == RecordingMode.climbing;
    final timerValue = climbing ? elapsedSeconds : restRemainingSeconds;
    final timerText = climbing ? formatDuration(timerValue) : formatSigned(timerValue);
    final color = climbing
        ? Theme.of(context).colorScheme.primary
        : restRemainingSeconds >= 0
            ? Theme.of(context).colorScheme.tertiary
            : Theme.of(context).colorScheme.error;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(climbing ? 'On wall' : 'Resting'),
                      Text(
                        routeName,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'End workout',
                  onPressed: onEndWorkout,
                  icon: const Icon(Icons.stop_circle_outlined),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Center(
              child: Text(
                timerText,
                style: Theme.of(context).textTheme.displayLarge?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: climbing ? onRest : onStart,
                icon: Icon(climbing ? Icons.pause : Icons.play_arrow),
                label: Text(climbing ? 'Rest' : 'Start next set'),
              ),
            ),
            if (!climbing) ...[
              const SizedBox(height: 8),
              Center(child: Text('Target rest ${formatDuration(targetRestSeconds)}')),
            ],
          ],
        ),
      ),
    );
  }
}

class _WorkoutSetTable extends StatelessWidget {
  const _WorkoutSetTable({
    required this.sets,
    required this.routes,
    required this.onEdit,
  });

  final List<WorkoutSet> sets;
  final List<RouteEntry> routes;
  final ValueChanged<WorkoutSet> onEdit;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Current workout', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Set')),
                  DataColumn(label: Text('Route')),
                  DataColumn(label: Text('Moves')),
                  DataColumn(label: Text('Wall')),
                  DataColumn(label: Text('Rest')),
                  DataColumn(label: Text('Speed')),
                  DataColumn(label: Text('')),
                ],
                rows: sets.map((set) {
                  final route = firstWhereOrNull(routes, (r) => r.id == set.routeId);
                  return DataRow(cells: [
                    DataCell(Text('${set.setNumber}')),
                    DataCell(Text(route?.name ?? 'Route')),
                    DataCell(Text('${set.movesCompleted}')),
                    DataCell(Text(formatDuration(set.wallTimeSeconds))),
                    DataCell(Text(set.restAfterSeconds == null
                        ? '...'
                        : formatDuration(set.restAfterSeconds!))),
                    DataCell(Text(set.movesPerMinute.toStringAsFixed(1))),
                    DataCell(IconButton(
                      tooltip: 'Edit set',
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: () => onEdit(set),
                    )),
                  ]);
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
