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
      version: 1,
      onCreate: _create,
      onOpen: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
    );
    return _db!;
  }

  Future<void> _create(Database db, int version) async {
    await db.execute('''
      CREATE TABLE routes(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        wall TEXT NOT NULL DEFAULT '',
        notes TEXT NOT NULL DEFAULT '',
        hold_count INTEGER,
        created_at INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE sessions(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        started_at INTEGER NOT NULL,
        ended_at INTEGER,
        target_rest_seconds INTEGER NOT NULL,
        notes TEXT NOT NULL DEFAULT ''
      )
    ''');
    await db.execute('''
      CREATE TABLE sets(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        session_id INTEGER NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
        route_id INTEGER NOT NULL REFERENCES routes(id),
        set_number INTEGER NOT NULL,
        started_at INTEGER NOT NULL,
        ended_at INTEGER NOT NULL,
        wall_time_seconds INTEGER NOT NULL,
        rest_after_seconds INTEGER,
        target_rest_seconds INTEGER NOT NULL,
        moves_completed INTEGER NOT NULL,
        notes TEXT NOT NULL DEFAULT ''
      )
    ''');
  }

  Future<List<RouteEntry>> routes() async {
    final rows = await (await db).query('routes', orderBy: 'name COLLATE NOCASE');
    return rows.map(RouteEntry.fromMap).toList();
  }

  Future<int> upsertRoute(RouteEntry route) async {
    if (route.id == null) {
      return (await db).insert('routes', route.toMap());
    }
    await (await db).update(
      'routes',
      route.toMap(),
      where: 'id = ?',
      whereArgs: [route.id],
    );
    return route.id!;
  }

  Future<void> deleteRoute(int id) async {
    await (await db).delete('routes', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> createSession(WorkoutSession session) async {
    return (await db).insert('sessions', session.toMap());
  }

  Future<void> updateSession(WorkoutSession session) async {
    await (await db).update(
      'sessions',
      session.toMap(),
      where: 'id = ?',
      whereArgs: [session.id],
    );
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
      orderBy: 'set_number ASC',
    );
    return rows.map(WorkoutSet.fromMap).toList();
  }

  Future<List<SetWithRoute>> allSets() async {
    final rows = await (await db).rawQuery('''
      SELECT sets.*, routes.name AS route_name, sessions.started_at AS session_started_at
      FROM sets
      JOIN routes ON routes.id = sets.route_id
      JOIN sessions ON sessions.id = sets.session_id
      ORDER BY sessions.started_at DESC, sets.set_number ASC
    ''');
    return rows
        .map(
          (row) => SetWithRoute(
            WorkoutSet.fromMap(row),
            row['route_name'] as String,
            DateTime.fromMillisecondsSinceEpoch(row['session_started_at'] as int),
          ),
        )
        .toList();
  }

  Future<int> insertSet(WorkoutSet set) async {
    return (await db).insert('sets', set.toMap());
  }

  Future<void> updateSet(WorkoutSet set) async {
    await (await db).update(
      'sets',
      set.toMap(),
      where: 'id = ?',
      whereArgs: [set.id],
    );
  }

  Future<void> updateRestAfter(int setId, int seconds) async {
    await (await db).update(
      'sets',
      {'rest_after_seconds': seconds},
      where: 'id = ?',
      whereArgs: [setId],
    );
  }

  Future<void> deleteSet(int id) async {
    await (await db).delete('sets', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteSession(int id) async {
    await (await db).delete('sessions', where: 'id = ?', whereArgs: [id]);
  }
}
