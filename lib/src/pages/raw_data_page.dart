import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:csv/csv.dart';

import '../database.dart';
import '../heart_rate_service.dart';
import '../models.dart';
import '../utils.dart';
import '../widgets/dialogs.dart';
import '../widgets/session_set_table.dart';

class RawDataPage extends StatefulWidget {
  const RawDataPage({super.key});

  @override
  State<RawDataPage> createState() => _RawDataPageState();
}

class _RawDataPageState extends State<RawDataPage> {
  final db = ClimbDatabase.instance;
  List<Exercise> _exercises = [];
  List<WorkoutSession> _sessions = [];
  List<SetWithExercise> _sets = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final exercises = await db.exercises();
    final sessions = await db.sessions();
    final sets = await db.allSets();
    if (!mounted) return;
    setState(() {
      _exercises = exercises;
      _sessions = sessions;
      _sets = sets;
    });
  }

  Future<void> _importCsv() async {
    final config = await showDialog<_CsvImportConfig>(
        context: context, builder: (_) => const _CsvImportDialog());
    if (config == null) return;
    try {
      final csvData = csv.decode(config.csvText);
      if (csvData.isEmpty) return;
      final headers = csvData.first.map((e) => e.toString().trim()).toList();
      final lookup = <String, int>{};
      for (var i = 0; i < headers.length; i++) {
        lookup[headers[i].toLowerCase()] = i;
      }
      final dateIndex = lookup[config.dateColumn.toLowerCase()];
      if (dateIndex == null) throw 'Date column not found';
      final exerciseColumnIndex = config.exerciseColumn.trim().isEmpty
          ? null
          : lookup[config.exerciseColumn.toLowerCase()];
      final repsColumns = _columnIndexes(config.repsColumns, lookup);
      final weightColumns = _columnIndexes(config.weightColumns, lookup);
      final movesColumns = _columnIndexes(config.movesColumns, lookup);
      final routeTypeColumns = _columnIndexes(config.routeTypeColumns, lookup);
      final difficultyColumns =
          _columnIndexes(config.difficultyColumns, lookup);
      final completedRouteColumns =
          _columnIndexes(config.completedRouteColumns, lookup);
      final distanceColumns = _columnIndexes(config.distanceColumns, lookup);
      final durationColumns = _columnIndexes(config.durationColumns, lookup);
      final restColumns = _columnIndexes(config.restColumns, lookup);
      final maxSets = [
        repsColumns,
        weightColumns,
        movesColumns,
        routeTypeColumns,
        difficultyColumns,
        completedRouteColumns,
        distanceColumns,
        durationColumns,
        restColumns,
      ]
          .map((items) => items.length)
          .fold<int>(1, (max, value) => value > max ? value : max);

      var importedSessions = 0;
      var importedSets = 0;
      for (final row in csvData.skip(1)) {
        if (row.length <= dateIndex) continue;
        final date = _parseDate(row[dateIndex].toString());
        if (date == null) continue;
        final exerciseName =
            exerciseColumnIndex == null || row.length <= exerciseColumnIndex
                ? config.defaultExercise
                : row[exerciseColumnIndex].toString().trim();
        if (exerciseName.isEmpty) continue;
        final exerciseId =
            await db.getOrCreateExercise(exerciseName, config.kind);
        final sessionId = await db.createSession(WorkoutSession(
          name: config.sessionName.trim().isEmpty
              ? 'Imported workout'
              : config.sessionName.trim(),
          startedAt: date,
          targetRestSeconds: config.defaultRestSeconds,
        ));
        var setNumber = 1;
        for (var i = 0; i < maxSets; i++) {
          final duration = _durationFrom(row, durationColumns, i) ?? 0;
          final rest = _durationFrom(row, restColumns, i);
          final reps = _intFrom(row, repsColumns, i);
          final weight = _doubleFrom(row, weightColumns, i);
          final moves = _intFrom(row, movesColumns, i);
          final routeType = _stringFrom(row, routeTypeColumns, i);
          final difficulty = _stringFrom(row, difficultyColumns, i);
          final completedRoute = _boolFrom(row, completedRouteColumns, i);
          final distance = _doubleFrom(row, distanceColumns, i);
          final hasMetric = [
                reps,
                weight,
                moves,
                routeType,
                difficulty,
                distance
              ].any((value) => value != null) ||
              duration > 0 ||
              rest != null;
          if (!hasMetric) continue;
          await db.insertSet(WorkoutSet(
            sessionId: sessionId,
            exerciseId: exerciseId,
            sequenceIndex: 0,
            setNumber: setNumber,
            startedAt: date,
            endedAt:
                duration > 0 ? date.add(Duration(seconds: duration)) : date,
            setDurationSeconds: duration,
            restAfterSeconds: rest,
            targetRestSeconds: config.defaultRestSeconds,
            reps: reps,
            weight: weight,
            moves: moves,
            routeType: routeType,
            difficulty: difficulty,
            completedRoute: completedRoute ?? false,
            distance: distance,
          ));
          setNumber++;
          importedSets++;
        }
        importedSessions++;
      }
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              'Imported $importedSessions sessions and $importedSets sets')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Import failed: $e')));
    }
  }

  List<int> _columnIndexes(String text, Map<String, int> lookup) {
    return text
        .split(',')
        .map((item) => item.trim().toLowerCase())
        .where((item) => item.isNotEmpty)
        .map((item) => lookup[item])
        .whereType<int>()
        .toList();
  }

  int? _intFrom(List<dynamic> row, List<int> columns, int index) =>
      _doubleFrom(row, columns, index)?.round();

  double? _doubleFrom(List<dynamic> row, List<int> columns, int index) {
    final column = _columnFor(columns, index);
    if (column == null || row.length <= column) return null;
    return double.tryParse(row[column].toString().trim());
  }

  bool? _boolFrom(List<dynamic> row, List<int> columns, int index) {
    final value = _stringFrom(row, columns, index)?.toLowerCase();
    if (value == null) return null;
    return value == 'true' || value == 'yes' || value == 'y' || value == '1';
  }

  String? _stringFrom(List<dynamic> row, List<int> columns, int index) {
    final column = _columnFor(columns, index);
    if (column == null || row.length <= column) return null;
    final value = row[column].toString().trim();
    return value.isEmpty ? null : value;
  }

  int? _durationFrom(List<dynamic> row, List<int> columns, int index) {
    final value = _stringFrom(row, columns, index);
    if (value == null) return null;
    return parseDuration(value) ?? double.tryParse(value)?.round();
  }

  int? _columnFor(List<int> columns, int index) {
    if (columns.isEmpty) return null;
    if (columns.length == 1) return columns.first;
    return index < columns.length ? columns[index] : null;
  }

  DateTime? _parseDate(String text) {
    final trimmed = text.trim();
    final iso = DateTime.tryParse(trimmed);
    if (iso != null) return iso;
    final slash = trimmed.split('/');
    if (slash.length == 3) {
      final month = int.tryParse(slash[0]);
      final day = int.tryParse(slash[1]);
      final yearRaw = int.tryParse(slash[2]);
      if (month != null && day != null && yearRaw != null) {
        final year = yearRaw < 100 ? 2000 + yearRaw : yearRaw;
        return DateTime(year, month, day);
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final setsBySession = <int, List<WorkoutSet>>{};
    for (final item in _sets) {
      setsBySession.putIfAbsent(item.set.sessionId, () => []).add(item.set);
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Raw Data',
            style: Theme.of(context)
                .textTheme
                .headlineMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: WrapAlignment.spaceBetween,
            children: [
              Text('Sessions', style: Theme.of(context).textTheme.titleLarge),
              FilledButton.icon(
                  onPressed: _addSession,
                  icon: const Icon(Icons.add),
                  label: const Text('Add session')),
              OutlinedButton.icon(
                  onPressed: _importCsv,
                  icon: const Icon(Icons.upload),
                  label: const Text('Import CSV')),
            ],
          ),
          const SizedBox(height: 8),
          ..._sessions.map((session) {
            final sessionSets = setsBySession[session.id] ?? [];
            final totalDuration = sessionSets.fold<int>(
                0,
                (sum, set) =>
                    sum + set.setDurationSeconds + (set.restAfterSeconds ?? 0));
            return Card(
              child: ExpansionTile(
                key: ValueKey(session.id),
                title: Text(
                    '${session.name} - ${dateFormat.format(session.startedAt)}'),
                subtitle: Text(
                    '${sessionSets.length} sets - ${formatDuration(totalDuration)}'),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                children: [
                  SessionSetTable(
                    sets: sessionSets,
                    exercises: _exercises,
                    onChanged: _updateSet,
                    onDelete: _deleteSet,
                    onAdd: () => _addSet(session.id!),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton.icon(
                          onPressed: () => _syncSessionHeartRate(session),
                          icon: const Icon(Icons.favorite_outline),
                          label: const Text('Sync HR')),
                      const SizedBox(width: 8),
                      TextButton.icon(
                          onPressed: () => _editSession(session),
                          icon: const Icon(Icons.edit_outlined),
                          label: const Text('Edit session')),
                      const SizedBox(width: 8),
                      TextButton.icon(
                          onPressed: () => _deleteSession(session),
                          icon: const Icon(Icons.delete_outline),
                          label: const Text('Delete session')),
                    ],
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Future<void> _syncSessionHeartRate(WorkoutSession session) async {
    final sessionId = session.id;
    if (sessionId == null) return;
    final status = await HeartRateService.instance.healthConnectStatus();
    if (status['available'] != true) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Health Connect is not available on this device')));
      return;
    }
    final granted = status['permissionsGranted'] == true ||
        await HeartRateService.instance.requestHealthConnectPermissions();
    if (!granted) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Health Connect heart rate permission is required')));
      return;
    }
    final sessionSets = await db.setsForSession(sessionId);
    final window = _heartRateSyncWindow(session, sessionSets);
    try {
      final samples =
          await HeartRateService.instance.readHealthConnectHeartRate(
        start: window.start,
        end: window.end,
      );
      for (final sample in samples) {
        await db.insertHeartRateSample(HeartRateSample(
          sessionId: sessionId,
          recordedAt: sample.recordedAt,
          bpm: sample.bpm,
          accuracy: sample.accuracy,
        ));
      }
      await db.recalculateHeartRateForSession(sessionId);
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              'Synced ${samples.length} HR samples from ${dateFormat.format(window.start)} to ${dateFormat.format(window.end)}')));
    } on PlatformException catch (error) {
      if (!mounted) return;
      final message = error.message?.trim().isNotEmpty == true
          ? error.message!
          : error.code;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Health Connect read failed: $message')));
    }
  }

  _HeartRateSyncWindow _heartRateSyncWindow(
      WorkoutSession session, List<WorkoutSet> sets) {
    var start = session.startedAt;
    var end = session.endedAt ?? session.startedAt;
    var hasOpenSet = false;

    for (final set in sets) {
      if (set.startedAt.isBefore(start)) start = set.startedAt;

      DateTime? setEnd;
      if (set.endedAt != null) {
        setEnd = set.endedAt;
      } else if (set.setDurationSeconds > 0) {
        setEnd = set.startedAt.add(Duration(seconds: set.setDurationSeconds));
      } else {
        hasOpenSet = true;
      }

      if (setEnd != null) {
        final rest = set.restAfterSeconds;
        if (rest != null && rest > 0) {
          setEnd = setEnd.add(Duration(seconds: rest));
        }
        if (setEnd.isAfter(end)) end = setEnd;
      }
    }

    if (hasOpenSet) end = DateTime.now();
    if (end.isBefore(start)) end = start;

    return _HeartRateSyncWindow(
      start.subtract(const Duration(minutes: 1)),
      end.add(const Duration(minutes: 1)),
    );
  }

  Future<void> _editSession(WorkoutSession session) async {
    final edited = await showDialog<WorkoutSession>(
        context: context, builder: (_) => SessionDialog(session: session));
    if (edited == null) return;
    await db.updateSession(edited);
    await _load();
  }

  Future<void> _addSession() async {
    final session = await showDialog<WorkoutSession>(
        context: context, builder: (_) => const NewSessionDialog());
    if (session == null) return;
    await db.createSession(session);
    await _load();
  }

  Future<void> _deleteSession(WorkoutSession session) async {
    final confirm = await _confirm(
        'Delete session', 'Remove this workout and all of its sets?');
    if (confirm != true || session.id == null) return;
    await db.deleteSession(session.id!);
    await _load();
  }

  Future<void> _updateSet(WorkoutSet set) async {
    await db.updateSet(set);
    await _load();
  }

  Future<void> _addSet(int sessionId) async {
    if (_exercises.isEmpty) return;
    final sessionSets =
        _sets.where((item) => item.set.sessionId == sessionId).toList();
    await db.insertSet(WorkoutSet(
      sessionId: sessionId,
      exerciseId: _exercises.first.id!,
      sequenceIndex: 0,
      setNumber: sessionSets.length + 1,
      startedAt: DateTime.now(),
      endedAt: DateTime.now(),
      setDurationSeconds: 0,
      restAfterSeconds: null,
      targetRestSeconds: 120,
    ));
    await _load();
  }

  Future<void> _deleteSet(int setId) async {
    final confirm =
        await _confirm('Delete set', 'Remove this set from the workout?');
    if (confirm != true) return;
    await db.deleteSet(setId);
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
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete')),
        ],
      ),
    );
  }
}

class _CsvImportDialog extends StatefulWidget {
  const _CsvImportDialog();

  @override
  State<_CsvImportDialog> createState() => _CsvImportDialogState();
}

class _CsvImportDialogState extends State<_CsvImportDialog> {
  final csvText = TextEditingController();
  final dateColumn = TextEditingController(text: 'date');
  final exerciseColumn = TextEditingController();
  final defaultExercise = TextEditingController(text: 'Bench press');
  final sessionName = TextEditingController(text: 'Imported workout');
  final defaultRest = TextEditingController(text: '2:00');
  final repsColumns = TextEditingController();
  final weightColumns = TextEditingController();
  final movesColumns = TextEditingController();
  final routeTypeColumns = TextEditingController();
  final difficultyColumns = TextEditingController();
  final completedRouteColumns = TextEditingController();
  final distanceColumns = TextEditingController();
  final durationColumns = TextEditingController();
  final restColumns = TextEditingController();
  ExerciseKind kind = ExerciseKind.strength;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Import CSV'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: csvText,
                maxLines: 8,
                decoration: const InputDecoration(
                    hintText: 'Paste CSV data here',
                    border: OutlineInputBorder()),
              ),
              TextField(
                  controller: dateColumn,
                  decoration: const InputDecoration(labelText: 'Date column')),
              TextField(
                  controller: exerciseColumn,
                  decoration: const InputDecoration(
                      labelText: 'Exercise column optional')),
              TextField(
                  controller: defaultExercise,
                  decoration:
                      const InputDecoration(labelText: 'Default exercise')),
              DropdownButtonFormField<ExerciseKind>(
                initialValue: kind,
                decoration:
                    const InputDecoration(labelText: 'Default exercise type'),
                items: ExerciseKind.values
                    .map((value) => DropdownMenuItem(
                        value: value, child: Text(value.label)))
                    .toList(),
                onChanged: (value) => setState(() => kind = value ?? kind),
              ),
              TextField(
                  controller: sessionName,
                  decoration: const InputDecoration(labelText: 'Session name')),
              TextField(
                  controller: defaultRest,
                  decoration:
                      const InputDecoration(labelText: 'Default target rest')),
              const SizedBox(height: 12),
              Text('Metric columns, comma separated for set1/set2/set3 columns',
                  style: Theme.of(context).textTheme.bodySmall),
              TextField(
                  controller: repsColumns,
                  decoration: const InputDecoration(labelText: 'Reps columns')),
              TextField(
                  controller: weightColumns,
                  decoration:
                      const InputDecoration(labelText: 'Weight columns')),
              TextField(
                  controller: movesColumns,
                  decoration:
                      const InputDecoration(labelText: 'Moves columns')),
              TextField(
                  controller: routeTypeColumns,
                  decoration: const InputDecoration(
                      labelText: 'Route type/color columns')),
              TextField(
                  controller: difficultyColumns,
                  decoration:
                      const InputDecoration(labelText: 'Difficulty columns')),
              TextField(
                  controller: completedRouteColumns,
                  decoration: const InputDecoration(
                      labelText: 'Finished route columns')),
              TextField(
                  controller: distanceColumns,
                  decoration:
                      const InputDecoration(labelText: 'Distance columns')),
              TextField(
                  controller: durationColumns,
                  decoration:
                      const InputDecoration(labelText: 'Duration columns')),
              TextField(
                  controller: restColumns,
                  decoration: const InputDecoration(labelText: 'Rest columns')),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            if (csvText.text.trim().isEmpty || dateColumn.text.trim().isEmpty) {
              return;
            }
            Navigator.pop(
                context,
                _CsvImportConfig(
                  csvText: csvText.text,
                  dateColumn: dateColumn.text.trim(),
                  exerciseColumn: exerciseColumn.text.trim(),
                  defaultExercise: defaultExercise.text.trim(),
                  kind: kind,
                  sessionName: sessionName.text.trim(),
                  defaultRestSeconds: parseDuration(defaultRest.text) ?? 120,
                  repsColumns: repsColumns.text,
                  weightColumns: weightColumns.text,
                  movesColumns: movesColumns.text,
                  routeTypeColumns: routeTypeColumns.text,
                  difficultyColumns: difficultyColumns.text,
                  completedRouteColumns: completedRouteColumns.text,
                  distanceColumns: distanceColumns.text,
                  durationColumns: durationColumns.text,
                  restColumns: restColumns.text,
                ));
          },
          child: const Text('Import'),
        ),
      ],
    );
  }
}

class _CsvImportConfig {
  _CsvImportConfig({
    required this.csvText,
    required this.dateColumn,
    required this.exerciseColumn,
    required this.defaultExercise,
    required this.kind,
    required this.sessionName,
    required this.defaultRestSeconds,
    required this.repsColumns,
    required this.weightColumns,
    required this.movesColumns,
    required this.routeTypeColumns,
    required this.difficultyColumns,
    required this.completedRouteColumns,
    required this.distanceColumns,
    required this.durationColumns,
    required this.restColumns,
  });

  final String csvText;
  final String dateColumn;
  final String exerciseColumn;
  final String defaultExercise;
  final ExerciseKind kind;
  final String sessionName;
  final int defaultRestSeconds;
  final String repsColumns;
  final String weightColumns;
  final String movesColumns;
  final String routeTypeColumns;
  final String difficultyColumns;
  final String completedRouteColumns;
  final String distanceColumns;
  final String durationColumns;
  final String restColumns;
}

class _HeartRateSyncWindow {
  const _HeartRateSyncWindow(this.start, this.end);

  final DateTime start;
  final DateTime end;
}
