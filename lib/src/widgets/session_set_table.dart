import 'package:flutter/material.dart';

import '../models.dart';
import '../utils.dart';

class SessionSetTable extends StatelessWidget {
  const SessionSetTable({
    super.key,
    required this.sets,
    required this.routes,
    required this.onChanged,
    required this.onDelete,
    required this.onAdd,
  });

  final List<WorkoutSet> sets;
  final List<RouteEntry> routes;
  final ValueChanged<WorkoutSet> onChanged;
  final ValueChanged<int> onDelete;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Sets', style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                FilledButton.icon(
                  onPressed: onAdd,
                  icon: const Icon(Icons.add),
                  label: const Text('Add set'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      SizedBox(width: 48, child: Text('Set', style: TextStyle(fontWeight: FontWeight.w600))),
                      SizedBox(width: 12),
                      SizedBox(width: 180, child: Text('Route', style: TextStyle(fontWeight: FontWeight.w600))),
                      SizedBox(width: 12),
                      SizedBox(width: 96, child: Text('Moves', style: TextStyle(fontWeight: FontWeight.w600))),
                      SizedBox(width: 12),
                      SizedBox(width: 96, child: Text('Rest', style: TextStyle(fontWeight: FontWeight.w600))),
                      SizedBox(width: 12),
                      SizedBox(width: 96, child: Text('Wall', style: TextStyle(fontWeight: FontWeight.w600))),
                      SizedBox(width: 12),
                      SizedBox(width: 48, child: Text('')),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (sets.isEmpty)
                    const Text('No sets yet')
                  else
                    ...sets.map((set) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: EditableWorkoutSetRow(
                          set: set,
                          routes: routes,
                          onChanged: onChanged,
                          onDelete: () => onDelete(set.id!),
                        ),
                      );
                    }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class EditableWorkoutSetRow extends StatefulWidget {
  const EditableWorkoutSetRow({
    super.key,
    required this.set,
    required this.routes,
    required this.onChanged,
    required this.onDelete,
  });

  final WorkoutSet set;
  final List<RouteEntry> routes;
  final ValueChanged<WorkoutSet> onChanged;
  final VoidCallback onDelete;

  @override
  State<EditableWorkoutSetRow> createState() => _EditableWorkoutSetRowState();
}

class _EditableWorkoutSetRowState extends State<EditableWorkoutSetRow> {
  late int routeId;
  late final TextEditingController movesController;
  late final TextEditingController restController;
  late final TextEditingController wallController;
  late final FocusNode movesFocus;
  late final FocusNode restFocus;
  late final FocusNode wallFocus;

  @override
  void initState() {
    super.initState();
    routeId = widget.set.routeId;
    movesController = TextEditingController(text: '${widget.set.movesCompleted}');
    restController = TextEditingController(text: widget.set.restAfterSeconds == null ? '' : formatDuration(widget.set.restAfterSeconds!));
    wallController = TextEditingController(text: formatDuration(widget.set.wallTimeSeconds));
    movesFocus = FocusNode()..addListener(_onFocusChange);
    restFocus = FocusNode()..addListener(_onFocusChange);
    wallFocus = FocusNode()..addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(covariant EditableWorkoutSetRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.set.id != oldWidget.set.id || widget.set.movesCompleted != oldWidget.set.movesCompleted || widget.set.wallTimeSeconds != oldWidget.set.wallTimeSeconds || widget.set.restAfterSeconds != oldWidget.set.restAfterSeconds) {
      routeId = widget.set.routeId;
      movesController.text = '${widget.set.movesCompleted}';
      restController.text = widget.set.restAfterSeconds == null ? '' : formatDuration(widget.set.restAfterSeconds!);
      wallController.text = formatDuration(widget.set.wallTimeSeconds);
    }
  }

  @override
  void dispose() {
    movesController.dispose();
    restController.dispose();
    wallController.dispose();
    movesFocus.dispose();
    restFocus.dispose();
    wallFocus.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (!movesFocus.hasFocus && !restFocus.hasFocus && !wallFocus.hasFocus) {
      _updateSet();
    }
  }

  void _updateSet() {
    final moves = int.tryParse(movesController.text) ?? widget.set.movesCompleted;
    final wallTime = parseDuration(wallController.text) ?? widget.set.wallTimeSeconds;
    final rest = restController.text.trim().isEmpty ? null : parseDuration(restController.text);
    widget.onChanged(widget.set.copyWith(
      routeId: routeId,
      movesCompleted: moves,
      wallTimeSeconds: wallTime,
      restAfterSeconds: rest,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 48, child: Text('${widget.set.setNumber}')),
        const SizedBox(width: 12),
        SizedBox(
          width: 180,
          child: DropdownButtonFormField<int>(
            initialValue: routeId,
            isExpanded: true,
            decoration: const InputDecoration(isDense: true, border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 12)),
            items: widget.routes
                .map((route) => DropdownMenuItem(value: route.id, child: Text(route.name)))
                .toList(),
            onChanged: (value) {
              if (value == null) return;
              setState(() => routeId = value);
              _updateSet();
            },
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 96,
          child: TextField(
            controller: movesController,
            focusNode: movesFocus,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(isDense: true, border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 12)),
            onEditingComplete: _updateSet,
            onSubmitted: (_) => _updateSet(),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 96,
          child: TextField(
            controller: restController,
            focusNode: restFocus,
            keyboardType: TextInputType.datetime,
            decoration: const InputDecoration(isDense: true, border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 12), hintText: 'm:ss'),
            onEditingComplete: _updateSet,
            onSubmitted: (_) => _updateSet(),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 96,
          child: TextField(
            controller: wallController,
            focusNode: wallFocus,
            keyboardType: TextInputType.datetime,
            decoration: const InputDecoration(isDense: true, border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 12), hintText: 'm:ss'),
            onEditingComplete: _updateSet,
            onSubmitted: (_) => _updateSet(),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 48,
          child: IconButton(
            tooltip: 'Delete set',
            onPressed: widget.onDelete,
            icon: const Icon(Icons.delete_outline),
          ),
        ),
      ],
    );
  }
}
