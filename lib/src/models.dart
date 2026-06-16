import 'dart:convert';

enum ExerciseKind {
  strength,
  calisthenic,
  climbing,
  aerobic,
  isometric,
  custom,
}

extension ExerciseKindDetails on ExerciseKind {
  String get label {
    switch (this) {
      case ExerciseKind.strength:
        return 'Strength';
      case ExerciseKind.calisthenic:
        return 'Calisthenic';
      case ExerciseKind.climbing:
        return 'Climbing';
      case ExerciseKind.aerobic:
        return 'Aerobic';
      case ExerciseKind.isometric:
        return 'Isometric';
      case ExerciseKind.custom:
        return 'Custom';
    }
  }

  List<String> get defaultMetrics {
    switch (this) {
      case ExerciseKind.strength:
        return ['reps', 'weight', 'volume', 'duration', 'rest'];
      case ExerciseKind.calisthenic:
        return ['reps', 'duration', 'rest'];
      case ExerciseKind.climbing:
        return [
          'moves',
          'difficulty',
          'routeCompletion',
          'movesPerMinute',
          'duration',
          'rest',
        ];
      case ExerciseKind.aerobic:
        return ['distance', 'duration', 'pace', 'rest'];
      case ExerciseKind.isometric:
        return ['duration', 'rest'];
      case ExerciseKind.custom:
        return ['duration', 'rest'];
    }
  }
}

ExerciseKind exerciseKindFromDb(String value) {
  switch (value) {
    case 'weighted':
      return ExerciseKind.strength;
    case 'bodyweight':
      return ExerciseKind.calisthenic;
    case 'climbingEndurance':
    case 'climbingPower':
      return ExerciseKind.climbing;
    case 'cardio':
      return ExerciseKind.aerobic;
    case 'staticHold':
      return ExerciseKind.isometric;
  }
  return ExerciseKind.values.firstWhere(
    (kind) => kind.name == value,
    orElse: () => ExerciseKind.custom,
  );
}

class Exercise {
  Exercise({
    this.id,
    required this.name,
    required this.kind,
    this.notes = '',
    List<String>? plotMetrics,
    required this.createdAt,
  }) : plotMetrics = plotMetrics ?? kind.defaultMetrics;

  final int? id;
  final String name;
  final ExerciseKind kind;
  final String notes;
  final List<String> plotMetrics;
  final DateTime createdAt;

  bool get recordsReps =>
      kind == ExerciseKind.strength || kind == ExerciseKind.calisthenic;
  bool get recordsWeight => kind == ExerciseKind.strength;
  bool get recordsMoves => kind == ExerciseKind.climbing;
  bool get recordsDifficulty => kind == ExerciseKind.climbing;
  bool get recordsRouteType => kind == ExerciseKind.climbing;
  bool get recordsRouteCompletion => kind == ExerciseKind.climbing;
  bool get recordsDistance => kind == ExerciseKind.aerobic;

  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'kind': kind.name,
        'notes': notes,
        'plot_metrics': jsonEncode(plotMetrics),
        'created_at': createdAt.millisecondsSinceEpoch,
      };

  static Exercise fromMap(Map<String, Object?> map) {
    final kind = exerciseKindFromDb(map['kind'] as String? ?? 'custom');
    final encodedMetrics = map['plot_metrics'] as String?;
    return Exercise(
      id: map['id'] as int?,
      name: map['name'] as String,
      kind: kind,
      notes: map['notes'] as String? ?? '',
      plotMetrics: encodedMetrics == null || encodedMetrics.isEmpty
          ? kind.defaultMetrics
          : (jsonDecode(encodedMetrics) as List)
              .map((e) => e.toString())
              .toList(),
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
    );
  }

  Exercise copyWith({
    int? id,
    String? name,
    ExerciseKind? kind,
    String? notes,
    List<String>? plotMetrics,
    DateTime? createdAt,
  }) {
    return Exercise(
      id: id ?? this.id,
      name: name ?? this.name,
      kind: kind ?? this.kind,
      notes: notes ?? this.notes,
      plotMetrics: plotMetrics ?? this.plotMetrics,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class WorkoutPlan {
  WorkoutPlan({
    this.id,
    required this.name,
    this.notes = '',
    this.cycleExercises = false,
    required this.createdAt,
  });

  final int? id;
  final String name;
  final String notes;
  final bool cycleExercises;
  final DateTime createdAt;

  String get orderLabel => cycleExercises ? 'Cycle all exercises' : 'Mixed order';

  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'notes': notes,
        'cycle_exercises': cycleExercises ? 1 : 0,
        'created_at': createdAt.millisecondsSinceEpoch,
      };

  static WorkoutPlan fromMap(Map<String, Object?> map) => WorkoutPlan(
        id: map['id'] as int?,
        name: map['name'] as String,
        notes: map['notes'] as String? ?? '',
        cycleExercises: (map['cycle_exercises'] as int? ?? 0) == 1,
        createdAt:
            DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      );

  WorkoutPlan copyWith({
    int? id,
    String? name,
    String? notes,
    bool? cycleExercises,
    DateTime? createdAt,
  }) {
    return WorkoutPlan(
      id: id ?? this.id,
      name: name ?? this.name,
      notes: notes ?? this.notes,
      cycleExercises: cycleExercises ?? this.cycleExercises,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class WorkoutPlanItem {
  WorkoutPlanItem({
    this.id,
    required this.planId,
    required this.exerciseId,
    required this.sequenceIndex,
    required this.sets,
    required this.targetRestSeconds,
    this.cycleGroup = 0,
    this.includeWarmup = false,
    this.warmupPercent,
    this.notes = '',
  });

  final int? id;
  final int planId;
  final int exerciseId;
  final int sequenceIndex;
  final int sets;
  final int targetRestSeconds;
  final int cycleGroup;
  final bool includeWarmup;
  final double? warmupPercent;
  final String notes;

  Map<String, Object?> toMap() => {
        'id': id,
        'plan_id': planId,
        'exercise_id': exerciseId,
        'sequence_index': sequenceIndex,
        'sets': sets,
        'target_rest_seconds': targetRestSeconds,
        'cycle_group': cycleGroup,
        'include_warmup': includeWarmup ? 1 : 0,
        'warmup_percent': warmupPercent,
        'notes': notes,
      };

  static WorkoutPlanItem fromMap(Map<String, Object?> map) => WorkoutPlanItem(
        id: map['id'] as int?,
        planId: map['plan_id'] as int,
        exerciseId: map['exercise_id'] as int,
        sequenceIndex: map['sequence_index'] as int,
        sets: map['sets'] as int,
        targetRestSeconds: map['target_rest_seconds'] as int,
        cycleGroup: map['cycle_group'] as int? ?? 0,
        includeWarmup: (map['include_warmup'] as int? ?? 0) == 1,
        warmupPercent: (map['warmup_percent'] as num?)?.toDouble(),
        notes: map['notes'] as String? ?? '',
      );

  WorkoutPlanItem copyWith({
    int? id,
    int? planId,
    int? exerciseId,
    int? sequenceIndex,
    int? sets,
    int? targetRestSeconds,
    int? cycleGroup,
    bool? includeWarmup,
    double? warmupPercent,
    String? notes,
  }) {
    return WorkoutPlanItem(
      id: id ?? this.id,
      planId: planId ?? this.planId,
      exerciseId: exerciseId ?? this.exerciseId,
      sequenceIndex: sequenceIndex ?? this.sequenceIndex,
      sets: sets ?? this.sets,
      targetRestSeconds: targetRestSeconds ?? this.targetRestSeconds,
      cycleGroup: cycleGroup ?? this.cycleGroup,
      includeWarmup: includeWarmup ?? this.includeWarmup,
      warmupPercent: warmupPercent ?? this.warmupPercent,
      notes: notes ?? this.notes,
    );
  }
}

class WorkoutPlanStep {
  WorkoutPlanStep(this.item, this.exercise);

  final WorkoutPlanItem item;
  final Exercise exercise;
}

class WorkoutSession {
  WorkoutSession({
    this.id,
    this.planId,
    required this.name,
    required this.startedAt,
    this.endedAt,
    required this.targetRestSeconds,
    this.notes = '',
  });

  final int? id;
  final int? planId;
  final String name;
  final DateTime startedAt;
  final DateTime? endedAt;
  final int targetRestSeconds;
  final String notes;

  Map<String, Object?> toMap() => {
        'id': id,
        'plan_id': planId,
        'name': name,
        'started_at': startedAt.millisecondsSinceEpoch,
        'ended_at': endedAt?.millisecondsSinceEpoch,
        'target_rest_seconds': targetRestSeconds,
        'notes': notes,
      };

  static WorkoutSession fromMap(Map<String, Object?> map) => WorkoutSession(
        id: map['id'] as int?,
        planId: map['plan_id'] as int?,
        name: map['name'] as String? ?? 'Workout',
        startedAt:
            DateTime.fromMillisecondsSinceEpoch(map['started_at'] as int),
        endedAt: map['ended_at'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(map['ended_at'] as int),
        targetRestSeconds: map['target_rest_seconds'] as int,
        notes: map['notes'] as String? ?? '',
      );

  WorkoutSession copyWith({
    int? id,
    int? planId,
    String? name,
    DateTime? startedAt,
    DateTime? endedAt,
    int? targetRestSeconds,
    String? notes,
  }) {
    return WorkoutSession(
      id: id ?? this.id,
      planId: planId ?? this.planId,
      name: name ?? this.name,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      targetRestSeconds: targetRestSeconds ?? this.targetRestSeconds,
      notes: notes ?? this.notes,
    );
  }
}

class WorkoutSet {
  WorkoutSet({
    this.id,
    required this.sessionId,
    required this.exerciseId,
    this.planItemId,
    required this.sequenceIndex,
    required this.setNumber,
    this.isWarmup = false,
    required this.startedAt,
    this.endedAt,
    required this.setDurationSeconds,
    this.restAfterSeconds,
    required this.targetRestSeconds,
    this.reps,
    this.weight,
    this.moves,
    this.routeType,
    this.difficulty,
    this.completedRoute = false,
    this.distance,
    this.notes = '',
  });

  final int? id;
  final int sessionId;
  final int exerciseId;
  final int? planItemId;
  final int sequenceIndex;
  final int setNumber;
  final bool isWarmup;
  final DateTime startedAt;
  final DateTime? endedAt;
  final int setDurationSeconds;
  final int? restAfterSeconds;
  final int targetRestSeconds;
  final int? reps;
  final double? weight;
  final int? moves;
  final String? routeType;
  final String? difficulty;
  final bool completedRoute;
  final double? distance;
  final String notes;

  double get movesPerMinute =>
      setDurationSeconds <= 0 ? 0 : (moves ?? 0) / setDurationSeconds * 60;
  double get volume => (reps ?? 0) * (weight ?? 0);
  double get pace =>
      distance == null || distance == 0 ? 0 : setDurationSeconds / distance!;

  Map<String, Object?> toMap() => {
        'id': id,
        'session_id': sessionId,
        'exercise_id': exerciseId,
        'plan_item_id': planItemId,
        'sequence_index': sequenceIndex,
        'set_number': setNumber,
        'is_warmup': isWarmup ? 1 : 0,
        'started_at': startedAt.millisecondsSinceEpoch,
        'ended_at': endedAt?.millisecondsSinceEpoch,
        'set_duration_seconds': setDurationSeconds,
        'rest_after_seconds': restAfterSeconds,
        'target_rest_seconds': targetRestSeconds,
        'reps': reps,
        'weight': weight,
        'moves': moves,
        'route_type': routeType,
        'difficulty': difficulty,
        'completed_route': completedRoute ? 1 : 0,
        'distance': distance,
        'notes': notes,
      };

  static WorkoutSet fromMap(Map<String, Object?> map) => WorkoutSet(
        id: map['id'] as int?,
        sessionId: map['session_id'] as int,
        exerciseId: map['exercise_id'] as int,
        planItemId: map['plan_item_id'] as int?,
        sequenceIndex: map['sequence_index'] as int? ?? 0,
        setNumber: map['set_number'] as int,
        isWarmup: (map['is_warmup'] as int? ?? 0) == 1,
        startedAt:
            DateTime.fromMillisecondsSinceEpoch(map['started_at'] as int),
        endedAt: map['ended_at'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(map['ended_at'] as int),
        setDurationSeconds: map['set_duration_seconds'] as int,
        restAfterSeconds: map['rest_after_seconds'] as int?,
        targetRestSeconds: map['target_rest_seconds'] as int,
        reps: map['reps'] as int?,
        weight: (map['weight'] as num?)?.toDouble(),
        moves: map['moves'] as int?,
        routeType: map['route_type'] as String?,
        difficulty: map['difficulty'] as String?,
        completedRoute: (map['completed_route'] as int? ?? 0) == 1,
        distance: (map['distance'] as num?)?.toDouble(),
        notes: map['notes'] as String? ?? '',
      );

  WorkoutSet copyWith({
    int? id,
    int? sessionId,
    int? exerciseId,
    int? planItemId,
    int? sequenceIndex,
    int? setNumber,
    bool? isWarmup,
    DateTime? startedAt,
    DateTime? endedAt,
    int? setDurationSeconds,
    int? restAfterSeconds,
    int? targetRestSeconds,
    int? reps,
    double? weight,
    int? moves,
    String? routeType,
    String? difficulty,
    bool? completedRoute,
    double? distance,
    String? notes,
  }) {
    return WorkoutSet(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      exerciseId: exerciseId ?? this.exerciseId,
      planItemId: planItemId ?? this.planItemId,
      sequenceIndex: sequenceIndex ?? this.sequenceIndex,
      setNumber: setNumber ?? this.setNumber,
      isWarmup: isWarmup ?? this.isWarmup,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      setDurationSeconds: setDurationSeconds ?? this.setDurationSeconds,
      restAfterSeconds: restAfterSeconds ?? this.restAfterSeconds,
      targetRestSeconds: targetRestSeconds ?? this.targetRestSeconds,
      reps: reps ?? this.reps,
      weight: weight ?? this.weight,
      moves: moves ?? this.moves,
      routeType: routeType ?? this.routeType,
      difficulty: difficulty ?? this.difficulty,
      completedRoute: completedRoute ?? this.completedRoute,
      distance: distance ?? this.distance,
      notes: notes ?? this.notes,
    );
  }
}

class SetWithExercise {
  SetWithExercise(
      this.set, this.exercise, this.sessionStartedAt, this.sessionName);

  final WorkoutSet set;
  final Exercise exercise;
  final DateTime sessionStartedAt;
  final String sessionName;
}

class MetricDefinition {
  const MetricDefinition(this.key, this.label, this.unit, this.value);

  final String key;
  final String label;
  final String unit;
  final double? Function(WorkoutSet set) value;
}

final metricDefinitions = <MetricDefinition>[
  MetricDefinition('duration', 'Set duration', 'sec',
      (set) => set.setDurationSeconds.toDouble()),
  MetricDefinition(
      'rest', 'Rest time', 'sec', (set) => set.restAfterSeconds?.toDouble()),
  MetricDefinition('reps', 'Reps', 'reps', (set) => set.reps?.toDouble()),
  MetricDefinition('weight', 'Weight', 'weight', (set) => set.weight),
  MetricDefinition('volume', 'Volume', 'weight x reps',
      (set) => set.volume == 0 ? null : set.volume),
  MetricDefinition('moves', 'Moves', 'moves', (set) => set.moves?.toDouble()),
  MetricDefinition('movesPerMinute', 'Moves per minute', 'moves/min',
      (set) => set.movesPerMinute == 0 ? null : set.movesPerMinute),
  MetricDefinition('difficulty', 'Difficulty', 'grade',
      (set) => difficultyToNumber(set.difficulty)),
  MetricDefinition('routeCompletion', 'Route completion', 'finished',
      (set) => set.completedRoute ? 1 : 0),
  MetricDefinition('distance', 'Distance', 'distance', (set) => set.distance),
  MetricDefinition(
      'pace', 'Pace', 'sec/distance', (set) => set.pace == 0 ? null : set.pace),
];

MetricDefinition? metricDefinition(String key) {
  for (final metric in metricDefinitions) {
    if (metric.key == key) return metric;
  }
  return null;
}

double? difficultyToNumber(String? value) {
  if (value == null || value.trim().isEmpty) return null;
  final cleaned = value.trim().toUpperCase();
  final boulder = RegExp(r'^V\s*(\d+(?:\.\d+)?)').firstMatch(cleaned);
  if (boulder != null) return double.tryParse(boulder.group(1)!);

  final yosemite = RegExp(r'5\.(\d{1,2})([ABCD+-]?)').firstMatch(cleaned);
  if (yosemite != null) {
    final number = double.tryParse(yosemite.group(1)!);
    if (number == null) return null;
    final suffix = yosemite.group(2);
    final offset = switch (suffix) {
      'A' => 0.1,
      'B' => 0.2,
      'C' => 0.3,
      'D' => 0.4,
      '+' => 0.05,
      '-' => -0.05,
      _ => 0.0,
    };
    return number + offset;
  }

  final numeric = cleaned.replaceAll(RegExp(r'[^0-9.]'), '');
  return double.tryParse(numeric);
}
