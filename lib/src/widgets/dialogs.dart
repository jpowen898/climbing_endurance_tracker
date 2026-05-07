import 'package:flutter/material.dart';

import '../models.dart';
import '../utils.dart';

class RouteDialog extends StatefulWidget {
  const RouteDialog({super.key, this.route});

  final RouteEntry? route;

  @override
  State<RouteDialog> createState() => _RouteDialogState();
}

class _RouteDialogState extends State<RouteDialog> {
  final name = TextEditingController();
  final wall = TextEditingController();
  final holds = TextEditingController();
  final notes = TextEditingController();

  @override
  void initState() {
    super.initState();
    final route = widget.route;
    if (route != null) {
      name.text = route.name;
      wall.text = route.wall;
      holds.text = route.holdCount?.toString() ?? '';
      notes.text = route.notes;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.route == null ? 'Add route' : 'Edit route'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: name, decoration: const InputDecoration(labelText: 'Name')),
            TextField(controller: wall, decoration: const InputDecoration(labelText: 'Wall')),
            TextField(
              controller: holds,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Total holds optional'),
            ),
            TextField(controller: notes, decoration: const InputDecoration(labelText: 'Notes')),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            if (name.text.trim().isEmpty) return;
            Navigator.pop(
              context,
              RouteEntry(
                id: widget.route?.id,
                name: name.text.trim(),
                wall: wall.text.trim(),
                notes: notes.text.trim(),
                holdCount: int.tryParse(holds.text),
                createdAt: widget.route?.createdAt ?? DateTime.now(),
              ),
            );
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class SessionDialog extends StatefulWidget {
  const SessionDialog({super.key, required this.session});

  final WorkoutSession session;

  @override
  State<SessionDialog> createState() => _SessionDialogState();
}

class _SessionDialogState extends State<SessionDialog> {
  late final restMinutes = TextEditingController(
    text: (widget.session.targetRestSeconds / 60).toStringAsFixed(1),
  );
  late final notes = TextEditingController(text: widget.session.notes);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit session'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(dateFormat.format(widget.session.startedAt)),
          TextField(
            controller: restMinutes,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Target rest minutes'),
          ),
          TextField(
            controller: notes,
            decoration: const InputDecoration(labelText: 'Notes'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final minutes = double.tryParse(restMinutes.text) ??
                widget.session.targetRestSeconds / 60;
            Navigator.pop(
              context,
              WorkoutSession(
                id: widget.session.id,
                startedAt: widget.session.startedAt,
                endedAt: widget.session.endedAt,
                targetRestSeconds: (minutes * 60).round(),
                notes: notes.text.trim(),
              ),
            );
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class WorkoutSetupDialog extends StatefulWidget {
  const WorkoutSetupDialog({super.key, required this.routes});

  final List<RouteEntry> routes;

  @override
  State<WorkoutSetupDialog> createState() => _WorkoutSetupDialogState();
}

class _WorkoutSetupDialogState extends State<WorkoutSetupDialog> {
  int? routeId;
  final newRoute = TextEditingController();
  final restMinutes = TextEditingController(text: '3');

  @override
  void initState() {
    super.initState();
    routeId = widget.routes.isEmpty ? null : widget.routes.first.id;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Start workout'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.routes.isNotEmpty)
            DropdownButtonFormField<int?>(
              initialValue: routeId,
              decoration: const InputDecoration(labelText: 'Starting route'),
              items: [
                ...widget.routes.map(
                  (r) => DropdownMenuItem(value: r.id, child: Text(r.name)),
                ),
                const DropdownMenuItem(value: null, child: Text('New route')),
              ],
              onChanged: (value) => setState(() => routeId = value),
            ),
          if (routeId == null || widget.routes.isEmpty)
            TextField(
              controller: newRoute,
              decoration: const InputDecoration(labelText: 'New route name'),
            ),
          TextField(
            controller: restMinutes,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Target rest minutes'),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            final minutes = double.tryParse(restMinutes.text) ?? 3;
            if (routeId == null && newRoute.text.trim().isEmpty) return;
            Navigator.pop(
              context,
              WorkoutSetupResult(
                routeId: routeId,
                newRouteName: routeId == null ? newRoute.text.trim() : null,
                targetRestSeconds: (minutes * 60).round(),
              ),
            );
          },
          child: const Text('Start'),
        ),
      ],
    );
  }
}

class SetEntryDialog extends StatefulWidget {
  const SetEntryDialog({
    super.key,
    required this.routes,
    required this.currentRouteId,
    required this.elapsedSeconds,
  });

  final List<RouteEntry> routes;
  final int currentRouteId;
  final int elapsedSeconds;

  @override
  State<SetEntryDialog> createState() => _SetEntryDialogState();
}

class _SetEntryDialogState extends State<SetEntryDialog> {
  final moves = TextEditingController();
  final notes = TextEditingController();
  final newRoute = TextEditingController();
  late int? nextRouteId;

  @override
  void initState() {
    super.initState();
    nextRouteId = widget.currentRouteId;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Log set'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Wall time ${formatDuration(widget.elapsedSeconds)}'),
            TextField(
              controller: moves,
              autofocus: true,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Moves completed'),
            ),
            DropdownButtonFormField<int?>(
              initialValue: nextRouteId,
              decoration: const InputDecoration(labelText: 'Next route'),
              items: [
                ...widget.routes.map(
                  (r) => DropdownMenuItem(value: r.id, child: Text(r.name)),
                ),
                const DropdownMenuItem(value: null, child: Text('New route')),
              ],
              onChanged: (value) => setState(() => nextRouteId = value),
            ),
            if (nextRouteId == null)
              TextField(
                controller: newRoute,
                decoration: const InputDecoration(labelText: 'New route name'),
              ),
            TextField(controller: notes, decoration: const InputDecoration(labelText: 'Notes')),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            final completed = int.tryParse(moves.text) ?? 0;
            if (completed == 0) return;
            Navigator.pop(
              context,
              SetEntryResult(
                movesCompleted: completed,
                nextRouteId: nextRouteId,
                newRouteName: nextRouteId == null ? newRoute.text.trim() : null,
                notes: notes.text.trim(),
              ),
            );
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class EditSetDialog extends StatefulWidget {
  const EditSetDialog({super.key, required this.set, required this.routes});

  final WorkoutSet set;
  final List<RouteEntry> routes;

  @override
  State<EditSetDialog> createState() => _EditSetDialogState();
}

class _EditSetDialogState extends State<EditSetDialog> {
  late int routeId = widget.set.routeId;
  late final moves = TextEditingController(text: '${widget.set.movesCompleted}');
  late final wall = TextEditingController(text: '${widget.set.wallTimeSeconds}');
  late final rest = TextEditingController(text: '${widget.set.restAfterSeconds ?? ''}');
  late final notes = TextEditingController(text: widget.set.notes);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit set'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<int>(
              initialValue: routeId,
              decoration: const InputDecoration(labelText: 'Route'),
              items: widget.routes
                  .map((r) => DropdownMenuItem(value: r.id, child: Text(r.name)))
                  .toList(),
              onChanged: (value) => setState(() => routeId = value ?? routeId),
            ),
            TextField(
              controller: moves,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Moves'),
            ),
            TextField(
              controller: wall,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Wall seconds'),
            ),
            TextField(
              controller: rest,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Rest after seconds'),
            ),
            TextField(controller: notes, decoration: const InputDecoration(labelText: 'Notes')),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            Navigator.pop(
              context,
              widget.set.copyWith(
                routeId: routeId,
                wallTimeSeconds: int.tryParse(wall.text) ?? widget.set.wallTimeSeconds,
                restAfterSeconds: rest.text.trim().isEmpty ? null : int.tryParse(rest.text),
                movesCompleted: int.tryParse(moves.text) ?? widget.set.movesCompleted,
                notes: notes.text.trim(),
              ),
            );
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class WorkoutSetupResult {
  WorkoutSetupResult({
    required this.routeId,
    required this.newRouteName,
    required this.targetRestSeconds,
  });

  final int? routeId;
  final String? newRouteName;
  final int targetRestSeconds;
}

class SetEntryResult {
  SetEntryResult({
    required this.movesCompleted,
    required this.nextRouteId,
    required this.newRouteName,
    required this.notes,
  });

  final int movesCompleted;
  final int? nextRouteId;
  final String? newRouteName;
  final String notes;
}
