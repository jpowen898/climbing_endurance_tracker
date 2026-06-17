import 'package:flutter/material.dart';

import '../models.dart';
import '../utils.dart';

class SessionSetTable extends StatelessWidget {
  const SessionSetTable({
    super.key,
    required this.sets,
    required this.exercises,
    required this.onChanged,
    required this.onDelete,
    required this.onAdd,
    this.visibleMetricKeys,
  });

  final List<WorkoutSet> sets;
  final List<Exercise> exercises;
  final ValueChanged<WorkoutSet> onChanged;
  final ValueChanged<int> onDelete;
  final VoidCallback onAdd;
  final Set<String>? visibleMetricKeys;

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
                  _HeaderRow(visibleMetricKeys: visibleMetricKeys),
                  const SizedBox(height: 8),
                  if (sets.isEmpty)
                    const Text('No sets yet')
                  else
                    ...sets.map((set) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: EditableWorkoutSetRow(
                          set: set,
                          exercises: exercises,
                          onChanged: onChanged,
                          onDelete: () => onDelete(set.id!),
                          visibleMetricKeys: visibleMetricKeys,
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

class _HeaderRow extends StatelessWidget {
  const _HeaderRow({required this.visibleMetricKeys});

  final Set<String>? visibleMetricKeys;

  bool _showMetric(String key) {
    return visibleMetricKeys == null || visibleMetricKeys!.contains(key);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _header('Set', 48),
        const SizedBox(width: 12),
        _header('Exercise', 190),
        if (_showMetric('duration')) ...[
          const SizedBox(width: 12),
          _header('Duration', 96)
        ],
        if (_showMetric('rest')) ...[
          const SizedBox(width: 12),
          _header('Rest', 96)
        ],
        if (_showMetric('reps')) ...[
          const SizedBox(width: 12),
          _header('Reps', 80)
        ],
        if (_showMetric('weight')) ...[
          const SizedBox(width: 12),
          _header('Weight', 92)
        ],
        if (_showMetric('moves')) ...[
          const SizedBox(width: 12),
          _header('Moves', 80)
        ],
        if (_showMetric('routeType')) ...[
          const SizedBox(width: 12),
          _header('Route', 110)
        ],
        if (_showMetric('difficulty')) ...[
          const SizedBox(width: 12),
          _header('Difficulty', 100)
        ],
        if (_showMetric('routeCompletion')) ...[
          const SizedBox(width: 12),
          _header('Finished', 92)
        ],
        if (_showMetric('distance')) ...[
          const SizedBox(width: 12),
          _header('Distance', 92)
        ],
        if (_showMetric('hrMin')) ...[
          const SizedBox(width: 12),
          _header('HR min', 80)
        ],
        if (_showMetric('hrAvg')) ...[
          const SizedBox(width: 12),
          _header('HR avg', 80)
        ],
        if (_showMetric('hrMax')) ...[
          const SizedBox(width: 12),
          _header('HR max', 80)
        ],
        const SizedBox(width: 12),
        const SizedBox(width: 48, child: Text('')),
      ],
    );
  }

  Widget _header(String label, double width) {
    return SizedBox(
      width: width,
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
    );
  }
}

class EditableWorkoutSetRow extends StatefulWidget {
  const EditableWorkoutSetRow({
    super.key,
    required this.set,
    required this.exercises,
    required this.onChanged,
    required this.onDelete,
    this.visibleMetricKeys,
  });

  final WorkoutSet set;
  final List<Exercise> exercises;
  final ValueChanged<WorkoutSet> onChanged;
  final VoidCallback onDelete;
  final Set<String>? visibleMetricKeys;

  @override
  State<EditableWorkoutSetRow> createState() => _EditableWorkoutSetRowState();
}

class _EditableWorkoutSetRowState extends State<EditableWorkoutSetRow> {
  late int exerciseId;
  late final TextEditingController durationController;
  late final TextEditingController restController;
  late final TextEditingController repsController;
  late final TextEditingController weightController;
  late final TextEditingController movesController;
  late final TextEditingController routeTypeController;
  late final TextEditingController difficultyController;
  late final TextEditingController distanceController;
  late bool completedRoute;
  final focusNodes = <FocusNode>[];

  @override
  void initState() {
    super.initState();
    exerciseId = widget.set.exerciseId;
    durationController = TextEditingController();
    restController = TextEditingController();
    repsController = TextEditingController();
    weightController = TextEditingController();
    movesController = TextEditingController();
    routeTypeController = TextEditingController();
    difficultyController = TextEditingController();
    distanceController = TextEditingController();
    completedRoute = widget.set.completedRoute;
    for (var i = 0; i < 8; i++) {
      focusNodes.add(FocusNode()..addListener(_onFocusChange));
    }
    _fillControllers();
  }

  @override
  void didUpdateWidget(covariant EditableWorkoutSetRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.set.id != oldWidget.set.id || widget.set != oldWidget.set) {
      exerciseId = widget.set.exerciseId;
      _fillControllers();
    }
  }

  void _fillControllers() {
    durationController.text = formatDuration(widget.set.setDurationSeconds);
    restController.text = widget.set.restAfterSeconds == null
        ? ''
        : formatDuration(widget.set.restAfterSeconds!);
    repsController.text = widget.set.reps?.toString() ?? '';
    weightController.text = widget.set.weight?.toString() ?? '';
    movesController.text = widget.set.moves?.toString() ?? '';
    routeTypeController.text = widget.set.routeType ?? '';
    difficultyController.text = widget.set.difficulty ?? '';
    completedRoute = widget.set.completedRoute;
    distanceController.text = widget.set.distance?.toString() ?? '';
  }

  @override
  void dispose() {
    durationController.dispose();
    restController.dispose();
    repsController.dispose();
    weightController.dispose();
    movesController.dispose();
    routeTypeController.dispose();
    difficultyController.dispose();
    distanceController.dispose();
    for (final node in focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _onFocusChange() {
    if (focusNodes.every((node) => !node.hasFocus)) _updateSet();
  }

  void _updateSet() {
    widget.onChanged(WorkoutSet(
      id: widget.set.id,
      sessionId: widget.set.sessionId,
      exerciseId: exerciseId,
      planItemId: widget.set.planItemId,
      sequenceIndex: widget.set.sequenceIndex,
      setNumber: widget.set.setNumber,
      isWarmup: widget.set.isWarmup,
      startedAt: widget.set.startedAt,
      endedAt: widget.set.endedAt,
      setDurationSeconds: parseDuration(durationController.text) ??
          widget.set.setDurationSeconds,
      restAfterSeconds: restController.text.trim().isEmpty
          ? null
          : parseDuration(restController.text),
      targetRestSeconds: widget.set.targetRestSeconds,
      reps: repsController.text.trim().isEmpty
          ? null
          : int.tryParse(repsController.text),
      weight: weightController.text.trim().isEmpty
          ? null
          : double.tryParse(weightController.text),
      moves: movesController.text.trim().isEmpty
          ? null
          : int.tryParse(movesController.text),
      routeType: routeTypeController.text.trim().isEmpty
          ? null
          : routeTypeController.text.trim(),
      difficulty: difficultyController.text.trim().isEmpty
          ? null
          : difficultyController.text.trim(),
      completedRoute: completedRoute,
      distance: distanceController.text.trim().isEmpty
          ? null
          : double.tryParse(distanceController.text),
      hrMin: widget.set.hrMin,
      hrMax: widget.set.hrMax,
      hrAvg: widget.set.hrAvg,
      notes: widget.set.notes,
    ));
  }

  bool _showMetric(String key) {
    return widget.visibleMetricKeys == null ||
        widget.visibleMetricKeys!.contains(key);
  }

  @override
  Widget build(BuildContext context) {
    final exercise = widget.exercises
        .where((item) => item.id == exerciseId)
        .cast<Exercise?>()
        .firstOrNull;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 48,
          child: Text(widget.set.isWarmup ? 'W' : '${widget.set.setNumber}'),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 190,
          child: DropdownButtonFormField<int>(
            initialValue: exerciseId,
            isExpanded: true,
            decoration: const InputDecoration(
                isDense: true,
                border: OutlineInputBorder(),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 8, vertical: 12)),
            items: widget.exercises
                .map((exercise) => DropdownMenuItem(
                    value: exercise.id, child: Text(exercise.name)))
                .toList(),
            onChanged: (value) {
              if (value == null) return;
              setState(() => exerciseId = value);
              _updateSet();
            },
          ),
        ),
        if (_showMetric('duration')) ...[
          const SizedBox(width: 12),
          _cell(durationController, focusNodes[0], TextInputType.datetime,
              'm:ss'),
        ],
        if (_showMetric('rest')) ...[
          const SizedBox(width: 12),
          _cell(restController, focusNodes[1], TextInputType.datetime, 'm:ss'),
        ],
        if (_showMetric('reps')) ...[
          const SizedBox(width: 12),
          _cell(repsController, focusNodes[2], TextInputType.number,
              exercise?.recordsReps == true ? '' : '-'),
        ],
        if (_showMetric('weight')) ...[
          const SizedBox(width: 12),
          _cell(weightController, focusNodes[3], TextInputType.number,
              exercise?.recordsWeight == true ? '' : '-'),
        ],
        if (_showMetric('moves')) ...[
          const SizedBox(width: 12),
          _cell(movesController, focusNodes[4], TextInputType.number,
              exercise?.recordsMoves == true ? '' : '-'),
        ],
        if (_showMetric('routeType')) ...[
          const SizedBox(width: 12),
          _cell(routeTypeController, focusNodes[5], TextInputType.text,
              exercise?.recordsRouteType == true ? '' : '-'),
        ],
        if (_showMetric('difficulty')) ...[
          const SizedBox(width: 12),
          _cell(difficultyController, focusNodes[6], TextInputType.text,
              exercise?.recordsDifficulty == true ? '' : '-'),
        ],
        if (_showMetric('routeCompletion')) ...[
          const SizedBox(width: 12),
          _checkboxCell(exercise?.recordsRouteCompletion == true),
        ],
        if (_showMetric('distance')) ...[
          const SizedBox(width: 12),
          _cell(distanceController, focusNodes[7], TextInputType.number,
              exercise?.recordsDistance == true ? '' : '-'),
        ],
        if (_showMetric('hrMin')) ...[
          const SizedBox(width: 12),
          _readOnlyCell(widget.set.hrMin),
        ],
        if (_showMetric('hrAvg')) ...[
          const SizedBox(width: 12),
          _readOnlyCell(widget.set.hrAvg),
        ],
        if (_showMetric('hrMax')) ...[
          const SizedBox(width: 12),
          _readOnlyCell(widget.set.hrMax),
        ],
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

  Widget _readOnlyCell(double? value) {
    return SizedBox(
      width: 80,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Text(value == null ? '-' : value.round().toString()),
      ),
    );
  }

  Widget _checkboxCell(bool enabled) {
    return SizedBox(
      width: 92,
      child: Checkbox(
        value: completedRoute,
        onChanged: enabled
            ? (value) {
                setState(() => completedRoute = value ?? false);
                _updateSet();
              }
            : null,
      ),
    );
  }

  Widget _cell(TextEditingController controller, FocusNode focusNode,
      TextInputType inputType, String hint) {
    return SizedBox(
      width: inputType == TextInputType.text ? 100 : 92,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        keyboardType: inputType,
        decoration: InputDecoration(
          isDense: true,
          border: const OutlineInputBorder(),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          hintText: hint,
        ),
        onEditingComplete: _updateSet,
        onSubmitted: (_) => _updateSet(),
      ),
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    if (!iterator.moveNext()) return null;
    return iterator.current;
  }
}
