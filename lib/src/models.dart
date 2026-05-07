class RouteEntry {
  RouteEntry({
    this.id,
    required this.name,
    this.wall = '',
    this.notes = '',
    this.holdCount,
    required this.createdAt,
  });

  final int? id;
  final String name;
  final String wall;
  final String notes;
  final int? holdCount;
  final DateTime createdAt;

  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'wall': wall,
        'notes': notes,
        'hold_count': holdCount,
        'created_at': createdAt.millisecondsSinceEpoch,
      };

  static RouteEntry fromMap(Map<String, Object?> map) => RouteEntry(
        id: map['id'] as int?,
        name: map['name'] as String,
        wall: map['wall'] as String? ?? '',
        notes: map['notes'] as String? ?? '',
        holdCount: map['hold_count'] as int?,
        createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      );

  RouteEntry copyWith({
    int? id,
    String? name,
    String? wall,
    String? notes,
    int? holdCount,
    DateTime? createdAt,
  }) {
    return RouteEntry(
      id: id ?? this.id,
      name: name ?? this.name,
      wall: wall ?? this.wall,
      notes: notes ?? this.notes,
      holdCount: holdCount ?? this.holdCount,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class WorkoutSession {
  WorkoutSession({
    this.id,
    required this.startedAt,
    this.endedAt,
    required this.targetRestSeconds,
    this.notes = '',
  });

  final int? id;
  final DateTime startedAt;
  final DateTime? endedAt;
  final int targetRestSeconds;
  final String notes;

  Map<String, Object?> toMap() => {
        'id': id,
        'started_at': startedAt.millisecondsSinceEpoch,
        'ended_at': endedAt?.millisecondsSinceEpoch,
        'target_rest_seconds': targetRestSeconds,
        'notes': notes,
      };

  static WorkoutSession fromMap(Map<String, Object?> map) => WorkoutSession(
        id: map['id'] as int?,
        startedAt: DateTime.fromMillisecondsSinceEpoch(map['started_at'] as int),
        endedAt: map['ended_at'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(map['ended_at'] as int),
        targetRestSeconds: map['target_rest_seconds'] as int,
        notes: map['notes'] as String? ?? '',
      );

  WorkoutSession copyWith({
    int? id,
    DateTime? startedAt,
    DateTime? endedAt,
    int? targetRestSeconds,
    String? notes,
  }) {
    return WorkoutSession(
      id: id ?? this.id,
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
    required this.routeId,
    required this.setNumber,
    required this.startedAt,
    this.endedAt,
    required this.wallTimeSeconds,
    this.restAfterSeconds,
    required this.targetRestSeconds,
    required this.movesCompleted,
    this.notes = '',
  });

  final int? id;
  final int sessionId;
  final int routeId;
  final int setNumber;
  final DateTime startedAt;
  final DateTime? endedAt;
  final int wallTimeSeconds;
  final int? restAfterSeconds;
  final int targetRestSeconds;
  final int movesCompleted;
  final String notes;

  double get movesPerMinute =>
      wallTimeSeconds <= 0 ? 0 : movesCompleted / wallTimeSeconds * 60;

  Map<String, Object?> toMap() => {
        'id': id,
        'session_id': sessionId,
        'route_id': routeId,
        'set_number': setNumber,
        'started_at': startedAt.millisecondsSinceEpoch,
        'ended_at': endedAt?.millisecondsSinceEpoch,
        'wall_time_seconds': wallTimeSeconds,
        'rest_after_seconds': restAfterSeconds,
        'target_rest_seconds': targetRestSeconds,
        'moves_completed': movesCompleted,
        'notes': notes,
      };

  static WorkoutSet fromMap(Map<String, Object?> map) => WorkoutSet(
        id: map['id'] as int?,
        sessionId: map['session_id'] as int,
        routeId: map['route_id'] as int,
        setNumber: map['set_number'] as int,
        startedAt: DateTime.fromMillisecondsSinceEpoch(map['started_at'] as int),
        endedAt: map['ended_at'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(map['ended_at'] as int),
        wallTimeSeconds: map['wall_time_seconds'] as int,
        restAfterSeconds: map['rest_after_seconds'] as int?,
        targetRestSeconds: map['target_rest_seconds'] as int,
        movesCompleted: map['moves_completed'] as int,
        notes: map['notes'] as String? ?? '',
      );

  WorkoutSet copyWith({
    int? id,
    int? sessionId,
    int? routeId,
    int? setNumber,
    DateTime? startedAt,
    DateTime? endedAt,
    int? wallTimeSeconds,
    int? restAfterSeconds,
    int? targetRestSeconds,
    int? movesCompleted,
    String? notes,
  }) {
    return WorkoutSet(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      routeId: routeId ?? this.routeId,
      setNumber: setNumber ?? this.setNumber,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      wallTimeSeconds: wallTimeSeconds ?? this.wallTimeSeconds,
      restAfterSeconds: restAfterSeconds ?? this.restAfterSeconds,
      targetRestSeconds: targetRestSeconds ?? this.targetRestSeconds,
      movesCompleted: movesCompleted ?? this.movesCompleted,
      notes: notes ?? this.notes,
    );
  }
}

class SetWithRoute {
  SetWithRoute(this.set, this.routeName, this.sessionStartedAt);

  final WorkoutSet set;
  final String routeName;
  final DateTime sessionStartedAt;
}
