import 'package:flutter/material.dart';

import '../database.dart';
import '../models.dart';
import '../utils.dart';
import '../widgets/dialogs.dart';

class WorkoutsPage extends StatefulWidget {
  const WorkoutsPage({super.key});

  @override
  State<WorkoutsPage> createState() => _WorkoutsPageState();
}

class _WorkoutsPageState extends State<WorkoutsPage> {
  final db = ClimbDatabase.instance;
  List<Exercise> _exercises = [];
  List<WorkoutPlan> _plans = [];
  final Map<int, List<WorkoutPlanStep>> _planSteps = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final exercises = await db.exercises();
    final plans = await db.workoutPlans();
    final steps = <int, List<WorkoutPlanStep>>{};
    for (final plan in plans) {
      if (plan.id != null) {
        steps[plan.id!] = await db.workoutPlanSteps(plan.id!);
      }
    }
    if (!mounted) return;
    setState(() {
      _exercises = exercises;
      _plans = plans;
      _planSteps
        ..clear()
        ..addAll(steps);
    });
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Workouts',
            style: Theme.of(context)
                .textTheme
                .headlineMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          _SectionHeader(
            title: 'Workout plans',
            action: 'Add workout',
            icon: Icons.add,
            onPressed: _addPlan,
          ),
          const SizedBox(height: 8),
          if (_plans.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('No workout plans yet'),
              ),
            )
          else
            ..._plans.map(_planCard),
          const SizedBox(height: 18),
          _SectionHeader(
            title: 'Exercises',
            action: 'Add exercise',
            icon: Icons.add,
            onPressed: _addExercise,
          ),
          const SizedBox(height: 8),
          ExpansionTile(
            title: Text('${_exercises.length} exercises'),
            children: _exercises
                .map(
                  (exercise) => Card(
                    child: ListTile(
                      title: Text(exercise.name),
                      subtitle: Text(
                        '${exercise.kind.label} - plots ${exercise.plotMetrics.join(', ')}',
                      ),
                      trailing: IconButton(
                        tooltip: 'Edit exercise',
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () => _editExercise(exercise),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _planCard(WorkoutPlan plan) {
    final steps = _planSteps[plan.id] ?? [];
    return Card(
      child: ExpansionTile(
        key: ValueKey('plan-${plan.id}'),
        title: Text(plan.name),
        subtitle: Text(
            '${steps.length} exercises - ${_planCycleSummary(plan, steps)}'),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          if (steps.isEmpty)
            const Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('No exercises in this workout'),
              ),
            )
          else
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: true,
              itemCount: steps.length,
              onReorder: (oldIndex, newIndex) =>
                  _reorderPlanItem(plan, oldIndex, newIndex),
              itemBuilder: (context, index) {
                final step = steps[index];
                return ListTile(
                  key: ValueKey('plan-${plan.id}-item-${step.item.id}'),
                  dense: true,
                  leading: Text('${index + 1}'),
                  title: Text(step.exercise.name),
                  subtitle: Text(_stepSubtitle(step)),
                  trailing: Wrap(
                    spacing: 4,
                    children: [
                      IconButton(
                        tooltip: 'Edit step',
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () => _editPlanItem(plan, step.item),
                      ),
                      IconButton(
                        tooltip: 'Delete step',
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _deletePlanItem(step.item),
                      ),
                    ],
                  ),
                );
              },
            ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: () => _addPlanItem(plan),
                icon: const Icon(Icons.add),
                label: const Text('Add exercise'),
              ),
              TextButton.icon(
                onPressed: () => _editPlan(plan),
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Edit workout'),
              ),
              TextButton.icon(
                onPressed: () => _deletePlan(plan),
                icon: const Icon(Icons.delete_outline),
                label: const Text('Delete'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _planCycleSummary(WorkoutPlan plan, List<WorkoutPlanStep> steps) {
    final groups = steps
        .map((step) => step.item.cycleGroup)
        .where((group) => group > 0)
        .toSet()
        .toList()
      ..sort();
    if (groups.isNotEmpty) {
      return 'mixed order - cycle groups ${groups.join(', ')}';
    }
    return plan.orderLabel;
  }

  String _stepSubtitle(WorkoutPlanStep step) {
    final parts = <String>[
      '${step.item.sets} sets',
      'rest ${formatDuration(step.item.targetRestSeconds)}',
    ];
    if (step.item.cycleGroup > 0) {
      parts.add('cycle group ${step.item.cycleGroup}');
    }
    if (step.item.includeWarmup) {
      parts.add('warmup ${((step.item.warmupPercent ?? 0.5) * 100).round()}%');
    }
    return parts.join(' - ');
  }

  Future<void> _addExercise() async {
    final exercise = await showDialog<Exercise>(
      context: context,
      builder: (_) => const ExerciseDialog(),
    );
    if (exercise == null) return;
    await db.upsertExercise(exercise);
    await _load();
  }

  Future<void> _editExercise(Exercise exercise) async {
    final edited = await showDialog<Exercise>(
      context: context,
      builder: (_) => ExerciseDialog(exercise: exercise),
    );
    if (edited == null) return;
    await db.upsertExercise(edited);
    await _load();
  }

  Future<void> _addPlan() async {
    final plan = await showDialog<WorkoutPlan>(
      context: context,
      builder: (_) => const WorkoutPlanDialog(),
    );
    if (plan == null) return;
    await db.upsertWorkoutPlan(plan);
    await _load();
  }

  Future<void> _editPlan(WorkoutPlan plan) async {
    final edited = await showDialog<WorkoutPlan>(
      context: context,
      builder: (_) => WorkoutPlanDialog(plan: plan),
    );
    if (edited == null) return;
    await db.upsertWorkoutPlan(edited);
    await _load();
  }

  Future<void> _deletePlan(WorkoutPlan plan) async {
    final confirm = await _confirm(
      'Delete workout',
      'Remove this workout plan? Recorded sessions stay in history.',
    );
    if (confirm != true || plan.id == null) return;
    await db.deleteWorkoutPlan(plan.id!);
    await _load();
  }

  Future<void> _addPlanItem(WorkoutPlan plan) async {
    if (plan.id == null || _exercises.isEmpty) return;
    final item = await showDialog<WorkoutPlanItem>(
      context: context,
      builder: (_) => WorkoutPlanItemDialog(
        planId: plan.id!,
        exercises: _exercises,
        sequenceIndex: (_planSteps[plan.id] ?? []).length,
      ),
    );
    if (item == null) return;
    await db.upsertWorkoutPlanItem(item);
    await _load();
  }

  Future<void> _editPlanItem(WorkoutPlan plan, WorkoutPlanItem existing) async {
    if (plan.id == null) return;
    final item = await showDialog<WorkoutPlanItem>(
      context: context,
      builder: (_) => WorkoutPlanItemDialog(
        planId: plan.id!,
        exercises: _exercises,
        sequenceIndex: existing.sequenceIndex,
        item: existing,
      ),
    );
    if (item == null) return;
    await db.upsertWorkoutPlanItem(item);
    await _load();
  }

  Future<void> _deletePlanItem(WorkoutPlanItem item) async {
    final confirm = await _confirm(
        'Delete exercise', 'Remove this exercise from the workout?');
    if (confirm != true || item.id == null) return;
    await db.deleteWorkoutPlanItem(item.id!);
    await _load();
  }

  Future<void> _reorderPlanItem(
      WorkoutPlan plan, int oldIndex, int newIndex) async {
    if (plan.id == null) return;
    final steps = List<WorkoutPlanStep>.from(
      _planSteps[plan.id!] ?? const <WorkoutPlanStep>[],
    );
    if (oldIndex < 0 || oldIndex >= steps.length) {
      return;
    }
    if (newIndex > oldIndex) {
      newIndex--;
    }
    final moved = steps.removeAt(oldIndex);
    steps.insert(newIndex, moved);
    setState(() => _planSteps[plan.id!] = steps);
    await db.reorderWorkoutPlanItems(steps.map((step) => step.item).toList());
    await _load();
  }

  Future<bool?> _confirm(String title, String body) {
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.action,
    required this.icon,
    required this.onPressed,
  });

  final String title;
  final String action;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        FilledButton.icon(
          onPressed: onPressed,
          icon: Icon(icon),
          label: Text(action),
        ),
      ],
    );
  }
}
