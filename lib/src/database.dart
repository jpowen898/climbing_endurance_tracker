import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'models.dart';

class ClimbDatabase {
  ClimbDatabase._();

  static final ClimbDatabase instance = ClimbDatabase._();
  Database? _db;

  Future<Database> get db async {
    if (_db != null) return _db!;
    final path = p.join(await getDatabasesPath(), 'climb_endurance.sqlite');
    _db = await openDatabase(
      path,
      version: 5,
      onCreate: _create,
      onUpgrade: _upgrade,
      onOpen: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
    );
    return _db!;
  }

  Future<void> _create(Database db, int version) async {
    await _createV3Tables(db);
    await _seedDefaults(db);
  }

  Future<void> _createV3Tables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS exercises(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE COLLATE NOCASE,
        kind TEXT NOT NULL,
        notes TEXT NOT NULL DEFAULT '',
        plot_metrics TEXT NOT NULL,
        created_at INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS workout_plans(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE COLLATE NOCASE,
        notes TEXT NOT NULL DEFAULT '',
        cycle_exercises INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS workout_plan_items(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        plan_id INTEGER NOT NULL REFERENCES workout_plans(id) ON DELETE CASCADE,
        exercise_id INTEGER NOT NULL REFERENCES exercises(id),
        sequence_index INTEGER NOT NULL,
        sets INTEGER NOT NULL,
        target_rest_seconds INTEGER NOT NULL,
        cycle_group INTEGER NOT NULL DEFAULT 0,
        include_warmup INTEGER NOT NULL DEFAULT 0,
        warmup_percent REAL,
        notes TEXT NOT NULL DEFAULT ''
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sessions(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        plan_id INTEGER REFERENCES workout_plans(id),
        name TEXT NOT NULL DEFAULT 'Workout',
        started_at INTEGER NOT NULL,
        ended_at INTEGER,
        target_rest_seconds INTEGER NOT NULL,
        notes TEXT NOT NULL DEFAULT ''
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sets(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        session_id INTEGER NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
        exercise_id INTEGER NOT NULL REFERENCES exercises(id),
        plan_item_id INTEGER REFERENCES workout_plan_items(id),
        sequence_index INTEGER NOT NULL DEFAULT 0,
        set_number INTEGER NOT NULL,
        is_warmup INTEGER NOT NULL DEFAULT 0,
        started_at INTEGER NOT NULL,
        ended_at INTEGER,
        set_duration_seconds INTEGER NOT NULL,
        rest_after_seconds INTEGER,
        target_rest_seconds INTEGER NOT NULL,
        reps INTEGER,
        weight REAL,
        moves INTEGER,
        route_type TEXT,
        difficulty TEXT,
        completed_route INTEGER NOT NULL DEFAULT 0,
        distance REAL,
        notes TEXT NOT NULL DEFAULT ''
      )
    ''');
  }

  Future<void> _upgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _upgradeToV2(db);
    }
    if (oldVersion < 3) {
      await _upgradeToV3(db);
    }
    if (oldVersion < 4) {
      await _upgradeToV4(db);
    }
    if (oldVersion < 5) {
      await _upgradeToV5(db);
    }
  }

  Future<void> _upgradeToV2(Database db) async {
    final tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'sets'",
    );
    if (tables.isEmpty) return;
    final columns = await db.rawQuery('PRAGMA table_info(sets)');
    final hasRest =
        columns.any((column) => column['name'] == 'rest_after_seconds');
    if (hasRest) return;
    await db.execute('ALTER TABLE sets ADD COLUMN rest_after_seconds INTEGER');
  }

  Future<void> _upgradeToV3(Database db) async {
    await db.execute('PRAGMA foreign_keys = OFF');
    final now = DateTime.now().millisecondsSinceEpoch;
    final hadRoutes = await _tableExists(db, 'routes');
    final hadOldSessions = await _tableExists(db, 'sessions');
    final hadOldSets = await _tableExists(db, 'sets');

    if (hadOldSessions) {
      await db.execute('ALTER TABLE sessions RENAME TO sessions_legacy');
    }
    if (hadOldSets) {
      await db.execute('ALTER TABLE sets RENAME TO sets_legacy');
    }

    await _createV3Tables(db);

    if (hadRoutes) {
      await db.execute('''
        INSERT OR IGNORE INTO exercises (id, name, kind, notes, plot_metrics, created_at)
        SELECT id, name, 'climbingEndurance',
               TRIM(COALESCE(wall, '') || CASE WHEN COALESCE(notes, '') = '' THEN '' ELSE ' - ' || notes END),
               '["moves","movesPerMinute","duration","rest"]',
               created_at
        FROM routes
      ''');
    }

    if ((await db.query('exercises', limit: 1)).isEmpty) {
      await db.insert(
          'exercises',
          Exercise(
            name: 'Endurance climb',
            kind: ExerciseKind.climbing,
            createdAt: DateTime.fromMillisecondsSinceEpoch(now),
          ).toMap());
    }

    if (hadOldSessions) {
      await db.execute('''
        INSERT INTO sessions (id, plan_id, name, started_at, ended_at, target_rest_seconds, notes)
        SELECT id, NULL, 'Climb endurance', started_at, ended_at, target_rest_seconds, notes
        FROM sessions_legacy
      ''');
    }

    if (hadOldSets) {
      final fallbackExercise = Sqflite.firstIntValue(
        await db.rawQuery('SELECT id FROM exercises ORDER BY id LIMIT 1'),
      )!;
      await db.execute('''
        INSERT INTO sets (
          id, session_id, exercise_id, plan_item_id, sequence_index, set_number,
          is_warmup, started_at, ended_at, set_duration_seconds, rest_after_seconds,
          target_rest_seconds, reps, weight, moves, route_type, difficulty,
          completed_route, distance, notes
        )
        SELECT sets_legacy.id, sets_legacy.session_id,
               COALESCE(exercises.id, $fallbackExercise), NULL, 0, sets_legacy.set_number,
               0, sets_legacy.started_at, sets_legacy.ended_at, sets_legacy.wall_time_seconds,
               sets_legacy.rest_after_seconds, sets_legacy.target_rest_seconds,
               NULL, NULL, sets_legacy.moves_completed, NULL, NULL, 0, NULL,
               sets_legacy.notes
        FROM sets_legacy
        LEFT JOIN exercises ON exercises.id = sets_legacy.route_id
      ''');
    }

    await _seedDefaults(db);
    if (hadOldSessions) await db.execute('DROP TABLE sessions_legacy');
    if (hadOldSets) await db.execute('DROP TABLE sets_legacy');
    await db.execute('PRAGMA foreign_keys = ON');
  }

  Future<void> _upgradeToV4(Database db) async {
    if (!await _columnExists(db, 'workout_plans', 'cycle_exercises')) {
      await db.execute(
          'ALTER TABLE workout_plans ADD COLUMN cycle_exercises INTEGER NOT NULL DEFAULT 0');
    }
  }

  Future<void> _upgradeToV5(Database db) async {
    if (!await _columnExists(db, 'workout_plan_items', 'cycle_group')) {
      await db.execute(
          'ALTER TABLE workout_plan_items ADD COLUMN cycle_group INTEGER NOT NULL DEFAULT 0');
    }
    if (!await _columnExists(db, 'sets', 'route_type')) {
      await db.execute('ALTER TABLE sets ADD COLUMN route_type TEXT');
    }
    if (!await _columnExists(db, 'sets', 'completed_route')) {
      await db.execute(
          'ALTER TABLE sets ADD COLUMN completed_route INTEGER NOT NULL DEFAULT 0');
    }
    await _seedDefaults(db);
  }

  Future<bool> _columnExists(
      Database db, String tableName, String columnName) async {
    final columns = await db.rawQuery('PRAGMA table_info($tableName)');
    return columns.any((column) => column['name'] == columnName);
  }

  Future<bool> _tableExists(Database db, String tableName) async {
    final rows = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name = ?",
      [tableName],
    );
    return rows.isNotEmpty;
  }

  Future<void> _seedDefaults(Database db) async {
    final now = DateTime.now();
    for (final exercise in [
      Exercise(
          name: 'Bench press', kind: ExerciseKind.strength, createdAt: now),
      Exercise(name: 'Dips', kind: ExerciseKind.calisthenic, createdAt: now),
      Exercise(
          name: 'Bicep curls', kind: ExerciseKind.strength, createdAt: now),
      Exercise(name: 'Pullups', kind: ExerciseKind.calisthenic, createdAt: now),
      Exercise(
          name: 'Climb endurance', kind: ExerciseKind.climbing, createdAt: now),
      Exercise(name: 'Bouldering', kind: ExerciseKind.climbing, createdAt: now),
      Exercise(
          name: 'Lead climbing', kind: ExerciseKind.climbing, createdAt: now),
      Exercise(name: 'Row machine', kind: ExerciseKind.aerobic, createdAt: now),
      Exercise(name: 'Run', kind: ExerciseKind.aerobic, createdAt: now),
      Exercise(name: 'Plank', kind: ExerciseKind.isometric, createdAt: now),
    ]) {
      await db.insert('exercises', exercise.toMap(),
          conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    if ((await db.query('workout_plans', limit: 1)).isEmpty) {
      final planId = await db.insert(
          'workout_plans',
          WorkoutPlan(
            name: 'General strength',
            notes: 'Starter plan. Edit or replace this with your own workout.',
            createdAt: DateTime.now(),
          ).toMap());
      final exercises = await db.query('exercises', orderBy: 'id ASC');
      for (var i = 0; i < exercises.take(3).length; i++) {
        await db.insert(
            'workout_plan_items',
            WorkoutPlanItem(
              planId: planId,
              exerciseId: exercises[i]['id'] as int,
              sequenceIndex: i,
              sets: 3,
              targetRestSeconds: 120,
              includeWarmup:
                  exerciseKindFromDb(exercises[i]['kind'] as String) ==
                      ExerciseKind.strength,
              warmupPercent: 0.5,
            ).toMap());
      }
    }
  }

  Future<List<Exercise>> exercises() async {
    final rows =
        await (await db).query('exercises', orderBy: 'name COLLATE NOCASE');
    return rows.map(Exercise.fromMap).toList();
  }

  Future<int> upsertExercise(Exercise exercise) async {
    if (exercise.id == null) {
      return (await db).insert('exercises', exercise.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await (await db).update('exercises', exercise.toMap(),
        where: 'id = ?', whereArgs: [exercise.id]);
    return exercise.id!;
  }

  Future<int> getOrCreateExercise(String name, ExerciseKind kind) async {
    final existing = await (await db)
        .query('exercises', where: 'name = ?', whereArgs: [name], limit: 1);
    if (existing.isNotEmpty) return Exercise.fromMap(existing.first).id!;
    return upsertExercise(
        Exercise(name: name, kind: kind, createdAt: DateTime.now()));
  }

  Future<void> deleteExercise(int id) async {
    await (await db).delete('exercises', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<WorkoutPlan>> workoutPlans() async {
    final rows =
        await (await db).query('workout_plans', orderBy: 'name COLLATE NOCASE');
    return rows.map(WorkoutPlan.fromMap).toList();
  }

  Future<int> upsertWorkoutPlan(WorkoutPlan plan) async {
    if (plan.id == null) {
      return (await db).insert('workout_plans', plan.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await (await db).update('workout_plans', plan.toMap(),
        where: 'id = ?', whereArgs: [plan.id]);
    return plan.id!;
  }

  Future<void> deleteWorkoutPlan(int id) async {
    await (await db).delete('workout_plans', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<WorkoutPlanStep>> workoutPlanSteps(int planId) async {
    final rows = await (await db).rawQuery('''
      SELECT workout_plan_items.*, exercises.name AS exercise_name, exercises.kind,
             exercises.notes AS exercise_notes, exercises.plot_metrics, exercises.created_at AS exercise_created_at
      FROM workout_plan_items
      JOIN exercises ON exercises.id = workout_plan_items.exercise_id
      WHERE workout_plan_items.plan_id = ?
      ORDER BY workout_plan_items.sequence_index ASC, workout_plan_items.id ASC
    ''', [planId]);
    return rows.map((row) {
      final exercise = Exercise.fromMap({
        'id': row['exercise_id'],
        'name': row['exercise_name'],
        'kind': row['kind'],
        'notes': row['exercise_notes'],
        'plot_metrics': row['plot_metrics'],
        'created_at': row['exercise_created_at'],
      });
      return WorkoutPlanStep(WorkoutPlanItem.fromMap(row), exercise);
    }).toList();
  }

  Future<int> upsertWorkoutPlanItem(WorkoutPlanItem item) async {
    if (item.id == null) {
      return (await db).insert('workout_plan_items', item.toMap());
    }
    await (await db).update('workout_plan_items', item.toMap(),
        where: 'id = ?', whereArgs: [item.id]);
    return item.id!;
  }

  Future<void> deleteWorkoutPlanItem(int id) async {
    await (await db)
        .delete('workout_plan_items', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> reorderWorkoutPlanItems(List<WorkoutPlanItem> items) async {
    final database = await db;
    final batch = database.batch();
    for (var i = 0; i < items.length; i++) {
      batch.update(
        'workout_plan_items',
        {'sequence_index': i},
        where: 'id = ?',
        whereArgs: [items[i].id],
      );
    }
    await batch.commit(noResult: true);
  }

  Future<double?> bestWeightForExercise(int exerciseId) async {
    final rows = await (await db).rawQuery('''
      SELECT MAX(weight) AS max_weight
      FROM sets
      WHERE exercise_id = ? AND weight IS NOT NULL AND is_warmup = 0
    ''', [exerciseId]);
    return (rows.first['max_weight'] as num?)?.toDouble();
  }

  Future<int> createSession(WorkoutSession session) async {
    return (await db).insert('sessions', session.toMap());
  }

  Future<void> updateSession(WorkoutSession session) async {
    await (await db).update('sessions', session.toMap(),
        where: 'id = ?', whereArgs: [session.id]);
  }

  Future<void> endSession(int id) async {
    await (await db).update(
      'sessions',
      {'ended_at': DateTime.now().millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<WorkoutSession>> sessions() async {
    final rows = await (await db).query('sessions', orderBy: 'started_at DESC');
    return rows.map(WorkoutSession.fromMap).toList();
  }

  Future<List<WorkoutSet>> setsForSession(int sessionId) async {
    final rows = await (await db).query(
      'sets',
      where: 'session_id = ?',
      whereArgs: [sessionId],
      orderBy: 'sequence_index ASC, is_warmup DESC, set_number ASC, id ASC',
    );
    return rows.map(WorkoutSet.fromMap).toList();
  }

  Future<List<SetWithExercise>> allSets() async {
    final rows = await (await db).rawQuery('''
      SELECT sets.*, sessions.started_at AS session_started_at, sessions.name AS session_name,
             exercises.name AS exercise_name, exercises.kind, exercises.notes AS exercise_notes,
             exercises.plot_metrics, exercises.created_at AS exercise_created_at
      FROM sets
      JOIN exercises ON exercises.id = sets.exercise_id
      JOIN sessions ON sessions.id = sets.session_id
      ORDER BY sessions.started_at DESC, sets.sequence_index ASC, sets.set_number ASC
    ''');
    return rows.map((row) {
      final exercise = Exercise.fromMap({
        'id': row['exercise_id'],
        'name': row['exercise_name'],
        'kind': row['kind'],
        'notes': row['exercise_notes'],
        'plot_metrics': row['plot_metrics'],
        'created_at': row['exercise_created_at'],
      });
      return SetWithExercise(
        WorkoutSet.fromMap(row),
        exercise,
        DateTime.fromMillisecondsSinceEpoch(row['session_started_at'] as int),
        row['session_name'] as String? ?? 'Workout',
      );
    }).toList();
  }

  Future<int> insertSet(WorkoutSet set) async {
    return (await db).insert('sets', set.toMap());
  }

  Future<void> updateSet(WorkoutSet set) async {
    await (await db)
        .update('sets', set.toMap(), where: 'id = ?', whereArgs: [set.id]);
  }

  Future<void> updateRestAfter(int setId, int seconds) async {
    await (await db).update('sets', {'rest_after_seconds': seconds},
        where: 'id = ?', whereArgs: [setId]);
  }

  Future<void> deleteSet(int id) async {
    await (await db).delete('sets', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteSession(int id) async {
    await (await db).delete('sessions', where: 'id = ?', whereArgs: [id]);
  }
}
