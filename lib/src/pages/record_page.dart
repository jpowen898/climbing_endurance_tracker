import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../active_workout_status.dart';
import '../database.dart';
import '../heart_rate_service.dart';
import '../models.dart';
import '../utils.dart';
import '../widgets/dialogs.dart';
import '../widgets/session_set_table.dart';

class RecordPage extends StatefulWidget {
  const RecordPage({super.key});

  @override
  State<RecordPage> createState() => _RecordPageState();
}

enum RecordingMode { idle, exercising, resting }

class _PlannedSet {
  _PlannedSet({
    required this.step,
    required this.queueIndex,
    required this.setNumber,
    required this.isWarmup,
  });

  final WorkoutPlanStep step;
  final int queueIndex;
  final int setNumber;
  final bool isWarmup;
}

class _RecordPageState extends State<RecordPage> {
  final db = ClimbDatabase.instance;
  Timer? _ticker;
  StreamSubscription<HeartRateReading>? _heartRateSubscription;
  List<Exercise> _exercises = [];
  List<WorkoutPlan> _plans = [];
  List<WorkoutPlanStep> _steps = [];
  List<_PlannedSet> _queue = [];
  List<WorkoutSet> _sets = [];
  RecordingMode _mode = RecordingMode.idle;
  int? _sessionId;
  int? _currentSetId;
  int _queueIndex = 0;
  int _targetRestSeconds = 120;
  DateTime? _phaseStartedAt;
  DateTime? _lastRestStartedAt;
  DateTime? _sessionStartedAt;
  DateTime? _lastHealthConnectPoll;
  bool _healthConnectReady = false;
  bool _healthConnectPolling = false;
  double? _currentHeartRate;
  String _heartRateStatus = 'Heart rate unavailable';

  @override
  void initState() {
    super.initState();
    _load();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _mode == RecordingMode.idle) return;
      setState(() {});
      _publishStatus();
      if (_healthConnectReady && !_healthConnectPolling) {
        final lastPoll = _lastHealthConnectPoll;
        if (lastPoll == null ||
            DateTime.now().difference(lastPoll) >=
                const Duration(seconds: 20)) {
          unawaited(_pollHealthConnectHeartRate());
        }
      }
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    unawaited(_stopHeartRate());
    super.dispose();
  }

  Future<void> _load() async {
    final exercises = await db.exercises();
    final plans = await db.workoutPlans();
    if (!mounted) return;
    setState(() {
      _exercises = exercises;
      _plans = plans;
    });
  }

  _PlannedSet? get _currentPlannedSet {
    if (_queueIndex < 0 || _queueIndex >= _queue.length) return null;
    return _queue[_queueIndex];
  }

  Set<String> get _visibleMetricKeys {
    final keys = <String>{'duration', 'rest', 'hrAvg', 'hrMax', 'hrMin'};
    for (final step in _steps) {
      if (step.exercise.recordsReps) keys.add('reps');
      if (step.exercise.recordsWeight) keys.add('weight');
      if (step.exercise.recordsMoves) keys.add('moves');
      if (step.exercise.recordsRouteType) keys.add('routeType');
      if (step.exercise.recordsDifficulty) keys.add('difficulty');
      if (step.exercise.recordsRouteCompletion) keys.add('routeCompletion');
      if (step.exercise.recordsDistance) keys.add('distance');
    }
    return keys;
  }

  Future<void> _startWorkout() async {
    await _load();
    if (!mounted) return;
    final planId = await showDialog<int>(
      context: context,
      builder: (_) => StartWorkoutDialog(plans: _plans),
    );
    if (planId == null) return;
    final plan = firstWhereOrNull(_plans, (item) => item.id == planId);
    final steps = await db.workoutPlanSteps(planId);
    if (!mounted) return;
    if (plan == null || steps.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add exercises to this workout first')),
      );
      return;
    }
    final queue = _buildQueue(plan, steps);
    if (queue.isEmpty) return;
    final workoutStartedAt = DateTime.now();
    final sessionId = await db.createSession(WorkoutSession(
      planId: plan.id,
      name: plan.name,
      startedAt: workoutStartedAt,
      targetRestSeconds: queue.first.step.item.targetRestSeconds,
    ));
    setState(() {
      _sessionId = sessionId;
      _steps = steps;
      _queue = queue;
      _queueIndex = 0;
      _sets = [];
      _sessionStartedAt = workoutStartedAt;
      _targetRestSeconds = queue.first.step.item.targetRestSeconds;
    });
    await _startHeartRate(sessionId);
    await _prepareHealthConnect();
    await _beginCurrentSet();
  }

  List<_PlannedSet> _buildQueue(WorkoutPlan plan, List<WorkoutPlanStep> steps) {
    final queue = <_PlannedSet>[];
    var queueIndex = 0;
    final hasStepGroups = steps.any((step) => step.item.cycleGroup > 0);
    final effectiveSteps = plan.cycleExercises && !hasStepGroups
        ? steps
            .map((step) => WorkoutPlanStep(
                  step.item.copyWith(cycleGroup: 1),
                  step.exercise,
                ))
            .toList()
        : steps;

    void addStraight(WorkoutPlanStep step) {
      if (step.item.includeWarmup) {
        queue.add(_PlannedSet(
            step: step,
            queueIndex: queueIndex++,
            setNumber: 0,
            isWarmup: true));
      }
      for (var setNumber = 1; setNumber <= step.item.sets; setNumber++) {
        queue.add(_PlannedSet(
            step: step,
            queueIndex: queueIndex++,
            setNumber: setNumber,
            isWarmup: false));
      }
    }

    void addCycled(List<WorkoutPlanStep> group) {
      final maxSets = group.fold<int>(
          0, (max, step) => step.item.sets > max ? step.item.sets : max);
      for (var setNumber = 1; setNumber <= maxSets; setNumber++) {
        for (final step in group) {
          if (setNumber == 1 && step.item.includeWarmup) {
            queue.add(_PlannedSet(
                step: step,
                queueIndex: queueIndex++,
                setNumber: 0,
                isWarmup: true));
          }
          if (setNumber <= step.item.sets) {
            queue.add(_PlannedSet(
                step: step,
                queueIndex: queueIndex++,
                setNumber: setNumber,
                isWarmup: false));
          }
        }
      }
    }

    var index = 0;
    while (index < effectiveSteps.length) {
      final step = effectiveSteps[index];
      final groupId = step.item.cycleGroup;
      if (groupId <= 0) {
        addStraight(step);
        index++;
        continue;
      }

      final group = <WorkoutPlanStep>[];
      while (index < effectiveSteps.length &&
          effectiveSteps[index].item.cycleGroup == groupId) {
        group.add(effectiveSteps[index]);
        index++;
      }
      if (group.length == 1) {
        addStraight(group.first);
      } else {
        addCycled(group);
      }
    }
    return queue;
  }

  Future<void> _startHeartRate(int sessionId) async {
    await _heartRateSubscription?.cancel();
    _currentHeartRate = null;
    final started = await HeartRateService.instance.start();
    if (!mounted) return;
    setState(() {
      _heartRateStatus = started
          ? 'Waiting for heart rate'
          : 'Heart rate unavailable or permission needed';
    });
    if (!started) return;
    _heartRateSubscription = HeartRateService.instance.readings.listen(
      (reading) {
        if (_sessionId != sessionId) return;
        setState(() {
          _currentHeartRate = reading.bpm;
          _heartRateStatus = 'Heart rate connected';
        });
        unawaited(db.insertHeartRateSample(HeartRateSample(
          sessionId: sessionId,
          recordedAt: reading.recordedAt,
          bpm: reading.bpm,
          accuracy: reading.accuracy,
        )));
      },
      onError: (_) {
        if (!mounted) return;
        setState(() => _heartRateStatus = 'Heart rate unavailable');
      },
    );
  }

  Future<void> _prepareHealthConnect() async {
    final status = await HeartRateService.instance.healthConnectStatus();
    final available = status['available'] == true;
    if (!available) return;
    final granted = status['permissionsGranted'] == true ||
        await HeartRateService.instance.requestHealthConnectPermissions();
    if (!mounted) return;
    setState(() {
      _heartRateStatus = granted
          ? 'Health Connect ready; waiting for heart rate'
          : 'Health Connect heart rate permission needed';
    });
    _healthConnectReady = granted;
    if (!granted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Health Connect heart rate permission was not granted'),
      ));
    } else {
      unawaited(_pollHealthConnectHeartRate());
    }
  }

  Future<void> _pollHealthConnectHeartRate() async {
    final sessionId = _sessionId;
    final startedAt = _sessionStartedAt;
    if (sessionId == null || startedAt == null || !_healthConnectReady) return;
    _healthConnectPolling = true;
    final pollStartedAt = DateTime.now();
    final start = _lastHealthConnectPoll == null
        ? startedAt.subtract(const Duration(minutes: 1))
        : _lastHealthConnectPoll!.subtract(const Duration(minutes: 2));
    try {
      final readings =
          await HeartRateService.instance.readHealthConnectHeartRate(
        start: start,
        end: DateTime.now().add(const Duration(seconds: 10)),
      );
      for (final reading in readings) {
        await db.insertHeartRateSample(HeartRateSample(
          sessionId: sessionId,
          recordedAt: reading.recordedAt,
          bpm: reading.bpm,
          accuracy: reading.accuracy,
        ));
      }
      if (!mounted) return;
      _lastHealthConnectPoll = pollStartedAt;
      if (readings.isNotEmpty) {
        final latest = readings
            .reduce((a, b) => a.recordedAt.isAfter(b.recordedAt) ? a : b);
        setState(() {
          _currentHeartRate = latest.bpm;
          _heartRateStatus =
              'Health Connect synced ${readings.length} HR samples';
        });
      } else {
        await _showLatestRecentHealthConnectHeartRate();
      }
    } on PlatformException catch (error) {
      _lastHealthConnectPoll = pollStartedAt;
      if (!mounted) return;
      setState(() => _heartRateStatus =
          'Health Connect read failed: ${_platformErrorMessage(error)}');
    } finally {
      _healthConnectPolling = false;
    }
  }

  Future<int> _syncHealthConnectHeartRate(
      int sessionId, DateTime start, DateTime end) async {
    final readings = await HeartRateService.instance.readHealthConnectHeartRate(
      start: start,
      end: end,
    );
    for (final reading in readings) {
      await db.insertHeartRateSample(HeartRateSample(
        sessionId: sessionId,
        recordedAt: reading.recordedAt,
        bpm: reading.bpm,
        accuracy: reading.accuracy,
      ));
    }
    return readings.length;
  }

  Future<void> _showLatestRecentHealthConnectHeartRate() async {
    try {
      final samples =
          await HeartRateService.instance.readHealthConnectHeartRate(
        start: DateTime.now().subtract(const Duration(minutes: 30)),
        end: DateTime.now().add(const Duration(seconds: 10)),
      );
      if (!mounted) return;
      if (samples.isEmpty) {
        setState(() =>
            _heartRateStatus = 'Health Connect ready; no watch HR synced yet');
        return;
      }
      final latest =
          samples.reduce((a, b) => a.recordedAt.isAfter(b.recordedAt) ? a : b);
      final age = DateTime.now().difference(latest.recordedAt);
      setState(() {
        if (age <= const Duration(minutes: 10)) {
          _currentHeartRate = latest.bpm;
          _heartRateStatus =
              'Latest Health Connect HR ${formatDuration(age.inSeconds)} ago';
        } else {
          _heartRateStatus =
              'Health Connect HR is stale; latest ${formatDuration(age.inSeconds)} ago';
        }
      });
    } on PlatformException catch (error) {
      if (!mounted) return;
      setState(() => _heartRateStatus =
          'Health Connect read failed: ${_platformErrorMessage(error)}');
    }
  }

  String _platformErrorMessage(PlatformException error) {
    final message = error.message;
    if (message != null && message.trim().isNotEmpty) return message;
    return error.code;
  }

  Future<void> _checkRecentHeartRate() async {
    final status = await HeartRateService.instance.healthConnectStatus();
    if (!mounted) return;
    if (status['available'] != true) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Health Connect is not available on this device')));
      return;
    }
    final granted = status['permissionsGranted'] == true ||
        await HeartRateService.instance.requestHealthConnectPermissions();
    if (!mounted) return;
    if (!granted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Health Connect heart rate permission is required')));
      return;
    }

    try {
      final samples =
          await HeartRateService.instance.readHealthConnectHeartRate(
        start: DateTime.now().subtract(const Duration(hours: 24)),
        end: DateTime.now().add(const Duration(minutes: 1)),
      );
      if (!mounted) return;
      if (samples.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('No Health Connect heart rate samples in 24 hours')));
        return;
      }
      final latest =
          samples.reduce((a, b) => a.recordedAt.isAfter(b.recordedAt) ? a : b);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              'Found ${samples.length} HR samples. Latest ${latest.bpm.round()} bpm at ${dateFormat.format(latest.recordedAt)}')));
    } on PlatformException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              'Health Connect read failed: ${_platformErrorMessage(error)}')));
    }
  }

  Future<void> _stopHeartRate() async {
    await _heartRateSubscription?.cancel();
    _heartRateSubscription = null;
    await HeartRateService.instance.stop();
  }

  Future<void> _beginCurrentSet() async {
    final sessionId = _sessionId;
    final planned = _currentPlannedSet;
    if (sessionId == null || planned == null) return;
    final now = DateTime.now();
    final setId = await db.insertSet(WorkoutSet(
      sessionId: sessionId,
      exerciseId: planned.step.exercise.id!,
      planItemId: planned.step.item.id,
      sequenceIndex: planned.queueIndex,
      setNumber: planned.setNumber,
      isWarmup: planned.isWarmup,
      startedAt: now,
      endedAt: null,
      setDurationSeconds: 0,
      restAfterSeconds: null,
      targetRestSeconds: planned.step.item.targetRestSeconds,
    ));
    final sets = await db.setsForSession(sessionId);
    if (!mounted) return;
    setState(() {
      _currentSetId = setId;
      _sets = sets;
      _mode = RecordingMode.exercising;
      _phaseStartedAt = now;
      _lastRestStartedAt = null;
      _targetRestSeconds = planned.step.item.targetRestSeconds;
    });
    await _publishStatus();
  }

  Future<void> _finishSet() async {
    final sessionId = _sessionId;
    final currentSetId = _currentSetId;
    final startedAt = _phaseStartedAt;
    final planned = _currentPlannedSet;
    if (sessionId == null ||
        currentSetId == null ||
        startedAt == null ||
        planned == null) {
      return;
    }

    final finishedAt = DateTime.now();
    final elapsed = math.max(1, finishedAt.difference(startedAt).inSeconds);
    final suggestedWeight = planned.step.item.includeWarmup && planned.isWarmup
        ? await _suggestedWarmupWeight(planned.step)
        : null;

    setState(() {
      _mode = RecordingMode.resting;
      _phaseStartedAt = finishedAt;
      _lastRestStartedAt = finishedAt;
      _targetRestSeconds = planned.step.item.targetRestSeconds;
    });
    await _publishStatus();

    if (!mounted) return;
    final entry = await showDialog<SetEntryResult>(
      context: context,
      barrierDismissible: false,
      builder: (_) => SetEntryDialog(
        exercise: planned.step.exercise,
        elapsedSeconds: elapsed,
        isWarmup: planned.isWarmup,
        suggestedWeight: suggestedWeight,
      ),
    );
    if (entry == null) return;
    await db.updateSet(WorkoutSet(
      id: currentSetId,
      sessionId: sessionId,
      exerciseId: planned.step.exercise.id!,
      planItemId: planned.step.item.id,
      sequenceIndex: planned.queueIndex,
      setNumber: planned.setNumber,
      isWarmup: planned.isWarmup,
      startedAt: startedAt,
      endedAt: finishedAt,
      setDurationSeconds: entry.durationSeconds,
      restAfterSeconds: null,
      targetRestSeconds: planned.step.item.targetRestSeconds,
      reps: entry.reps,
      weight: entry.weight,
      moves: entry.moves,
      routeType: entry.routeType,
      difficulty: entry.difficulty,
      completedRoute: entry.completedRoute,
      distance: entry.distance,
      hrMin: firstWhereOrNull(_sets, (set) => set.id == currentSetId)?.hrMin,
      hrMax: firstWhereOrNull(_sets, (set) => set.id == currentSetId)?.hrMax,
      hrAvg: firstWhereOrNull(_sets, (set) => set.id == currentSetId)?.hrAvg,
      notes: entry.notes,
    ));
    await db.recalculateHeartRateForSet(currentSetId);
    final sets = await db.setsForSession(sessionId);
    if (!mounted) return;
    setState(() => _sets = sets);
  }

  Future<double?> _suggestedWarmupWeight(WorkoutPlanStep step) async {
    final best = await db.bestWeightForExercise(step.exercise.id!);
    if (best == null) return null;
    return best * (step.item.warmupPercent ?? 0.5);
  }

  Future<void> _startNextSet() async {
    final sessionId = _sessionId;
    final completedSetId = _currentSetId;
    if (sessionId == null) return;
    final restStartedAt = _lastRestStartedAt;
    if (completedSetId != null && restStartedAt != null) {
      await db.updateRestAfter(
          completedSetId, DateTime.now().difference(restStartedAt).inSeconds);
    }

    if (_queueIndex + 1 >= _queue.length) {
      await _endWorkout();
      return;
    }
    setState(() => _queueIndex++);
    await _beginCurrentSet();
  }

  Future<void> _endWorkout() async {
    final id = _sessionId;
    if (id == null) return;
    final startedAt = _sessionStartedAt;
    if (startedAt != null) {
      try {
        final synced = await _syncHealthConnectHeartRate(
          id,
          startedAt.subtract(const Duration(minutes: 1)),
          DateTime.now().add(const Duration(minutes: 1)),
        );
        if (mounted && synced > 0) {
          setState(
              () => _heartRateStatus = 'Synced $synced Health Connect samples');
        }
      } on PlatformException catch (error) {
        if (mounted) {
          setState(() => _heartRateStatus =
              'Health Connect read failed: ${_platformErrorMessage(error)}');
        }
      }
    }
    await db.recalculateHeartRateForSession(id);
    await db.endSession(id);
    await _stopHeartRate();
    setState(() {
      _mode = RecordingMode.idle;
      _sessionId = null;
      _currentSetId = null;
      _steps = [];
      _queue = [];
      _sets = [];
      _phaseStartedAt = null;
      _lastRestStartedAt = null;
      _sessionStartedAt = null;
      _lastHealthConnectPoll = null;
      _healthConnectReady = false;
      _healthConnectPolling = false;
      _queueIndex = 0;
      _currentHeartRate = null;
      _heartRateStatus = 'Heart rate unavailable';
    });
    await ActiveWorkoutStatus.instance.clear();
    await _load();
  }

  int get _elapsedSeconds => _phaseStartedAt == null
      ? 0
      : DateTime.now().difference(_phaseStartedAt!).inSeconds;
  int get _restRemaining => _targetRestSeconds - _elapsedSeconds;

  Future<void> _publishStatus() async {
    final planned = _currentPlannedSet;
    if (_mode == RecordingMode.idle || planned == null) {
      await ActiveWorkoutStatus.instance.clear();
      return;
    }
    await ActiveWorkoutStatus.instance.update(ActiveWorkoutSnapshot(
      active: true,
      resting: _mode == RecordingMode.resting,
      title: planned.step.exercise.name,
      detail: _progressText(planned),
      timerSeconds: _elapsedSeconds,
      targetRestSeconds: _targetRestSeconds,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final planned = _currentPlannedSet;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Workout Tracker',
          style: Theme.of(context)
              .textTheme
              .headlineMedium
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 16),
        if (_mode == RecordingMode.idle)
          _IdlePanel(
              onStart: _startWorkout,
              onCheckHeartRate: _checkRecentHeartRate,
              planCount: _plans.length,
              exerciseCount: _exercises.length)
        else if (planned != null)
          _ActivePanel(
            mode: _mode,
            exerciseName: planned.step.exercise.name,
            progress: _progressText(planned),
            elapsedSeconds: _elapsedSeconds,
            restRemainingSeconds: _restRemaining,
            targetRestSeconds: _targetRestSeconds,
            onFinishSet: _finishSet,
            onStartNext: _startNextSet,
            currentHeartRate: _currentHeartRate,
            heartRateStatus: _heartRateStatus,
            onEndWorkout: _endWorkout,
          ),
        const SizedBox(height: 16),
        if (_sets.isNotEmpty)
          SessionSetTable(
            sets: _sets,
            exercises: _exercises,
            visibleMetricKeys: _visibleMetricKeys,
            onChanged: _updateSet,
            onDelete: _deleteSet,
            onAdd: _addManualSet,
          ),
      ],
    );
  }

  String _progressText(_PlannedSet planned) {
    final position = 'Step ${_queueIndex + 1}/${_queue.length}';
    if (planned.isWarmup) return '$position - warmup';
    return '$position - set ${planned.setNumber}/${planned.step.item.sets}';
  }

  Future<void> _updateSet(WorkoutSet set) async {
    await db.updateSet(set);
    if (_sessionId != null) {
      final sets = await db.setsForSession(_sessionId!);
      setState(() => _sets = sets);
    }
  }

  Future<void> _addManualSet() async {
    if (_sessionId == null || _exercises.isEmpty) return;
    final planned = _currentPlannedSet;
    final exerciseId = planned?.step.exercise.id ?? _exercises.first.id!;
    final sessionSets = _sets
        .where((set) => set.exerciseId == exerciseId && !set.isWarmup)
        .toList();
    final newSet = WorkoutSet(
      sessionId: _sessionId!,
      exerciseId: exerciseId,
      sequenceIndex: planned?.queueIndex ?? _sets.length,
      setNumber: sessionSets.length + 1,
      startedAt: DateTime.now(),
      endedAt: DateTime.now(),
      setDurationSeconds: 0,
      restAfterSeconds: null,
      targetRestSeconds: _targetRestSeconds,
    );
    await db.insertSet(newSet);
    final sets = await db.setsForSession(_sessionId!);
    setState(() => _sets = sets);
  }

  Future<void> _deleteSet(int setId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete set'),
        content: const Text('Remove this set from the current workout?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (confirm != true) return;
    await db.deleteSet(setId);
    if (_sessionId != null) {
      final sets = await db.setsForSession(_sessionId!);
      setState(() => _sets = sets);
    }
  }
}

class _IdlePanel extends StatelessWidget {
  const _IdlePanel(
      {required this.onStart,
      required this.onCheckHeartRate,
      required this.planCount,
      required this.exerciseCount});

  final VoidCallback onStart;
  final VoidCallback onCheckHeartRate;
  final int planCount;
  final int exerciseCount;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Ready to record',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text('$planCount workouts - $exerciseCount exercises'),
            const SizedBox(height: 20),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: planCount == 0 ? null : onStart,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Start workout'),
                ),
                OutlinedButton.icon(
                  onPressed: onCheckHeartRate,
                  icon: const Icon(Icons.favorite_outline),
                  label: const Text('Check watch HR'),
                ),
              ],
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
    required this.exerciseName,
    required this.progress,
    required this.elapsedSeconds,
    required this.restRemainingSeconds,
    required this.targetRestSeconds,
    required this.currentHeartRate,
    required this.heartRateStatus,
    required this.onFinishSet,
    required this.onStartNext,
    required this.onEndWorkout,
  });

  final RecordingMode mode;
  final String exerciseName;
  final String progress;
  final int elapsedSeconds;
  final int restRemainingSeconds;
  final int targetRestSeconds;
  final double? currentHeartRate;
  final String heartRateStatus;
  final VoidCallback onFinishSet;
  final VoidCallback onStartNext;
  final VoidCallback onEndWorkout;

  @override
  Widget build(BuildContext context) {
    final exercising = mode == RecordingMode.exercising;
    final timerValue = exercising ? elapsedSeconds : restRemainingSeconds;
    final timerText =
        exercising ? formatDuration(timerValue) : formatSigned(timerValue);
    final color = exercising
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
                      Text(exercising ? 'Working' : 'Resting'),
                      Text(exerciseName,
                          style: Theme.of(context).textTheme.headlineSmall),
                      const SizedBox(height: 4),
                      Text(progress),
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
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.favorite_outline, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(currentHeartRate == null
                          ? heartRateStatus
                          : '${currentHeartRate!.round()} bpm'),
                      if (currentHeartRate != null &&
                          heartRateStatus.isNotEmpty)
                        Text(
                          heartRateStatus,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Center(
              child: Text(
                timerText,
                style: Theme.of(context)
                    .textTheme
                    .displayLarge
                    ?.copyWith(color: color, fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: exercising ? onFinishSet : onStartNext,
                icon: Icon(exercising ? Icons.check : Icons.play_arrow),
                label: Text(exercising ? 'Finish set' : 'Start next'),
              ),
            ),
            if (!exercising) ...[
              const SizedBox(height: 8),
              Center(
                  child:
                      Text('Target rest ${formatDuration(targetRestSeconds)}')),
            ],
          ],
        ),
      ),
    );
  }
}
