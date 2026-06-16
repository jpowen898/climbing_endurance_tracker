import 'package:flutter/material.dart';

import '../models.dart';
import '../utils.dart';

class ExerciseDialog extends StatefulWidget {
  const ExerciseDialog({super.key, this.exercise});

  final Exercise? exercise;

  @override
  State<ExerciseDialog> createState() => _ExerciseDialogState();
}

class _ExerciseDialogState extends State<ExerciseDialog> {
  final name = TextEditingController();
  final notes = TextEditingController();
  late ExerciseKind kind;
  late Set<String> plotMetrics;

  @override
  void initState() {
    super.initState();
    final exercise = widget.exercise;
    kind = exercise?.kind ?? ExerciseKind.weighted;
    name.text = exercise?.name ?? '';
    notes.text = exercise?.notes ?? '';
    plotMetrics = {...(exercise?.plotMetrics ?? kind.defaultMetrics)};
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.exercise == null ? 'Add exercise' : 'Edit exercise'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Name')),
            DropdownButtonFormField<ExerciseKind>(
              initialValue: kind,
              decoration: const InputDecoration(labelText: 'Type'),
              items: ExerciseKind.values
                  .map((value) =>
                      DropdownMenuItem(value: value, child: Text(value.label)))
                  .toList(),
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  kind = value;
                  plotMetrics = {...value.defaultMetrics};
                });
              },
            ),
            TextField(
                controller: notes,
                decoration: const InputDecoration(labelText: 'Notes')),
            const SizedBox(height: 14),
            Text('Plots', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: metricDefinitions.map((metric) {
                return FilterChip(
                  label: Text(metric.label),
                  selected: plotMetrics.contains(metric.key),
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        plotMetrics.add(metric.key);
                      } else {
                        plotMetrics.remove(metric.key);
                      }
                    });
                  },
                );
              }).toList(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            if (name.text.trim().isEmpty) return;
            Navigator.pop(
              context,
              Exercise(
                id: widget.exercise?.id,
                name: name.text.trim(),
                kind: kind,
                notes: notes.text.trim(),
                plotMetrics: plotMetrics.isEmpty
                    ? kind.defaultMetrics
                    : plotMetrics.toList(),
                createdAt: widget.exercise?.createdAt ?? DateTime.now(),
              ),
            );
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class WorkoutPlanDialog extends StatefulWidget {
  const WorkoutPlanDialog({super.key, this.plan});

  final WorkoutPlan? plan;

  @override
  State<WorkoutPlanDialog> createState() => _WorkoutPlanDialogState();
}

class _WorkoutPlanDialogState extends State<WorkoutPlanDialog> {
  final name = TextEditingController();
  final notes = TextEditingController();
  late bool cycleExercises;

  @override
  void initState() {
    super.initState();
    name.text = widget.plan?.name ?? '';
    notes.text = widget.plan?.notes ?? '';
    cycleExercises = widget.plan?.cycleExercises ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.plan == null ? 'Add workout' : 'Edit workout'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
              controller: name,
              decoration: const InputDecoration(labelText: 'Workout name')),
          TextField(
              controller: notes,
              decoration: const InputDecoration(labelText: 'Notes')),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: cycleExercises,
            title: const Text('Cycle exercises'),
            subtitle:
                const Text('Do set 1 for each exercise, then set 2, and so on'),
            onChanged: (value) => setState(() => cycleExercises = value),
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            if (name.text.trim().isEmpty) return;
            Navigator.pop(
              context,
              WorkoutPlan(
                id: widget.plan?.id,
                name: name.text.trim(),
                notes: notes.text.trim(),
                cycleExercises: cycleExercises,
                createdAt: widget.plan?.createdAt ?? DateTime.now(),
              ),
            );
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class WorkoutPlanItemDialog extends StatefulWidget {
  const WorkoutPlanItemDialog({
    super.key,
    required this.planId,
    required this.exercises,
    required this.sequenceIndex,
    this.item,
  });

  final int planId;
  final List<Exercise> exercises;
  final int sequenceIndex;
  final WorkoutPlanItem? item;

  @override
  State<WorkoutPlanItemDialog> createState() => _WorkoutPlanItemDialogState();
}

class _WorkoutPlanItemDialogState extends State<WorkoutPlanItemDialog> {
  int? exerciseId;
  final sets = TextEditingController(text: '3');
  final rest = TextEditingController(text: '2:00');
  final warmupPercent = TextEditingController(text: '50');
  final notes = TextEditingController();
  bool includeWarmup = false;

  Exercise? get selectedExercise {
    for (final exercise in widget.exercises) {
      if (exercise.id == exerciseId) return exercise;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    exerciseId = item?.exerciseId ??
        (widget.exercises.isEmpty ? null : widget.exercises.first.id);
    if (item != null) {
      sets.text = '${item.sets}';
      rest.text = formatDuration(item.targetRestSeconds);
      includeWarmup = item.includeWarmup;
      warmupPercent.text =
          ((item.warmupPercent ?? 0.5) * 100).round().toString();
      notes.text = item.notes;
    }
  }

  @override
  Widget build(BuildContext context) {
    final exercise = selectedExercise;
    final weighted = exercise?.kind == ExerciseKind.weighted;
    return AlertDialog(
      title: Text(
          widget.item == null ? 'Add exercise step' : 'Edit exercise step'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<int>(
              initialValue: exerciseId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Exercise'),
              items: widget.exercises
                  .map((exercise) => DropdownMenuItem(
                      value: exercise.id, child: Text(exercise.name)))
                  .toList(),
              onChanged: (value) => setState(() => exerciseId = value),
            ),
            TextField(
              controller: sets,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Sets'),
            ),
            TextField(
              controller: rest,
              keyboardType: TextInputType.datetime,
              decoration: const InputDecoration(
                  labelText: 'Target rest', hintText: 'm:ss'),
            ),
            if (weighted)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: includeWarmup,
                title: const Text('Warmup set'),
                onChanged: (value) => setState(() => includeWarmup = value),
              ),
            if (weighted && includeWarmup)
              TextField(
                controller: warmupPercent,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    labelText: 'Warmup percent of best weight'),
              ),
            TextField(
                controller: notes,
                decoration: const InputDecoration(labelText: 'Notes')),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            if (exerciseId == null) return;
            Navigator.pop(
              context,
              WorkoutPlanItem(
                id: widget.item?.id,
                planId: widget.planId,
                exerciseId: exerciseId!,
                sequenceIndex:
                    widget.item?.sequenceIndex ?? widget.sequenceIndex,
                sets: int.tryParse(sets.text) ?? 3,
                targetRestSeconds: parseDuration(rest.text) ?? 120,
                includeWarmup: includeWarmup && weighted,
                warmupPercent:
                    ((double.tryParse(warmupPercent.text) ?? 50) / 100)
                        .clamp(0.05, 1.0),
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

class StartWorkoutDialog extends StatefulWidget {
  const StartWorkoutDialog({super.key, required this.plans});

  final List<WorkoutPlan> plans;

  @override
  State<StartWorkoutDialog> createState() => _StartWorkoutDialogState();
}

class _StartWorkoutDialogState extends State<StartWorkoutDialog> {
  int? planId;

  @override
  void initState() {
    super.initState();
    planId = widget.plans.isEmpty ? null : widget.plans.first.id;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Start workout'),
      content: DropdownButtonFormField<int>(
        initialValue: planId,
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'Workout'),
        items: widget.plans
            .map((plan) =>
                DropdownMenuItem(value: plan.id, child: Text(plan.name)))
            .toList(),
        onChanged: (value) => setState(() => planId = value),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        FilledButton(
          onPressed:
              planId == null ? null : () => Navigator.pop(context, planId),
          child: const Text('Start'),
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
  late final name = TextEditingController(text: widget.session.name);
  late final restDuration = TextEditingController(
      text: formatDuration(widget.session.targetRestSeconds));
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
              controller: name,
              decoration: const InputDecoration(labelText: 'Name')),
          TextField(
            controller: restDuration,
            keyboardType: TextInputType.datetime,
            decoration: const InputDecoration(
                labelText: 'Default target rest', hintText: 'm:ss'),
          ),
          TextField(
              controller: notes,
              decoration: const InputDecoration(labelText: 'Notes')),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            Navigator.pop(
              context,
              widget.session.copyWith(
                name: name.text.trim().isEmpty
                    ? widget.session.name
                    : name.text.trim(),
                targetRestSeconds: parseDuration(restDuration.text) ??
                    widget.session.targetRestSeconds,
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

class NewSessionDialog extends StatefulWidget {
  const NewSessionDialog({super.key, this.name = 'Manual workout'});

  final String name;

  @override
  State<NewSessionDialog> createState() => _NewSessionDialogState();
}

class _NewSessionDialogState extends State<NewSessionDialog> {
  DateTime startedAt = DateTime.now();
  final name = TextEditingController();
  final restDuration = TextEditingController(text: '2:00');
  final notes = TextEditingController();

  @override
  void initState() {
    super.initState();
    name.text = widget.name;
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: startedAt,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null) return;
    setState(() => startedAt = DateTime(picked.year, picked.month, picked.day,
        startedAt.hour, startedAt.minute));
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
        context: context, initialTime: TimeOfDay.fromDateTime(startedAt));
    if (picked == null) return;
    setState(() => startedAt = DateTime(startedAt.year, startedAt.month,
        startedAt.day, picked.hour, picked.minute));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New session'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                  child: FilledButton(
                      onPressed: _pickDate,
                      child: Text(shortDate.format(startedAt)))),
              const SizedBox(width: 12),
              Expanded(
                  child: FilledButton(
                      onPressed: _pickTime,
                      child: Text(
                          TimeOfDay.fromDateTime(startedAt).format(context)))),
            ],
          ),
          TextField(
              controller: name,
              decoration: const InputDecoration(labelText: 'Name')),
          TextField(
            controller: restDuration,
            keyboardType: TextInputType.datetime,
            decoration: const InputDecoration(
                labelText: 'Default target rest', hintText: 'm:ss'),
          ),
          TextField(
              controller: notes,
              decoration: const InputDecoration(labelText: 'Notes')),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            Navigator.pop(
              context,
              WorkoutSession(
                name: name.text.trim().isEmpty
                    ? 'Manual workout'
                    : name.text.trim(),
                startedAt: startedAt,
                targetRestSeconds: parseDuration(restDuration.text) ?? 120,
                notes: notes.text.trim(),
              ),
            );
          },
          child: const Text('Create'),
        ),
      ],
    );
  }
}

class SetEntryDialog extends StatefulWidget {
  const SetEntryDialog({
    super.key,
    required this.exercise,
    required this.elapsedSeconds,
    this.initial,
    this.isWarmup = false,
    this.suggestedWeight,
  });

  final Exercise exercise;
  final int elapsedSeconds;
  final WorkoutSet? initial;
  final bool isWarmup;
  final double? suggestedWeight;

  @override
  State<SetEntryDialog> createState() => _SetEntryDialogState();
}

class _SetEntryDialogState extends State<SetEntryDialog> {
  final reps = TextEditingController();
  final weight = TextEditingController();
  final moves = TextEditingController();
  final difficulty = TextEditingController();
  final distance = TextEditingController();
  final duration = TextEditingController();
  final notes = TextEditingController();

  @override
  void initState() {
    super.initState();
    final set = widget.initial;
    reps.text = set?.reps?.toString() ?? '';
    weight.text = set?.weight?.toString() ??
        (widget.suggestedWeight == null
            ? ''
            : widget.suggestedWeight!.toStringAsFixed(1));
    moves.text = set?.moves?.toString() ?? '';
    difficulty.text = set?.difficulty ?? '';
    distance.text = set?.distance?.toString() ?? '';
    duration.text =
        formatDuration(set?.setDurationSeconds ?? widget.elapsedSeconds);
    notes.text = set?.notes ?? '';
  }

  @override
  Widget build(BuildContext context) {
    final exercise = widget.exercise;
    return AlertDialog(
      title: Text(widget.isWarmup ? 'Log warmup' : 'Log set'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(exercise.name),
            TextField(
              controller: duration,
              keyboardType: TextInputType.datetime,
              decoration: const InputDecoration(
                  labelText: 'Set duration', hintText: 'm:ss'),
            ),
            if (exercise.recordsReps)
              TextField(
                  controller: reps,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Reps')),
            if (exercise.recordsWeight)
              TextField(
                  controller: weight,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Weight')),
            if (exercise.recordsMoves)
              TextField(
                  controller: moves,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Moves')),
            if (exercise.recordsDifficulty)
              TextField(
                  controller: difficulty,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: 'Difficulty')),
            if (exercise.recordsDistance)
              TextField(
                  controller: distance,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Distance')),
            TextField(
                controller: notes,
                decoration: const InputDecoration(labelText: 'Notes')),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            Navigator.pop(
              context,
              SetEntryResult(
                durationSeconds:
                    parseDuration(duration.text) ?? widget.elapsedSeconds,
                reps: int.tryParse(reps.text),
                weight: double.tryParse(weight.text),
                moves: int.tryParse(moves.text),
                difficulty: difficulty.text.trim().isEmpty
                    ? null
                    : difficulty.text.trim(),
                distance: double.tryParse(distance.text),
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

class SetEntryResult {
  SetEntryResult({
    required this.durationSeconds,
    this.reps,
    this.weight,
    this.moves,
    this.difficulty,
    this.distance,
    required this.notes,
  });

  final int durationSeconds;
  final int? reps;
  final double? weight;
  final int? moves;
  final String? difficulty;
  final double? distance;
  final String notes;
}
