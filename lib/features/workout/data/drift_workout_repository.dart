import 'package:collection/collection.dart';
import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/upsert.dart';
import '../../../core/database/watch_tables.dart';
import '../../../core/domain/clock.dart';
import '../../exercises/domain/exercise.dart';
import '../../progress/domain/metrics.dart';
import '../domain/workout_repository.dart';
import '../domain/workout_session.dart';

final class DriftWorkoutRepository implements WorkoutRepository {
  DriftWorkoutRepository(this._db, this._clock);

  final AppDatabase _db;
  final Clock _clock;

  @override
  Stream<WorkoutSession?> watchActive() => watchTables(_db, 'workout', {
    _db.workoutSessions,
    _db.sessionExercises,
    _db.sessionSets,
  }).asyncMap((_) => findActive());

  @override
  Future<WorkoutSession?> findActive() async {
    final row =
        await (_db.select(_db.workoutSessions)..where(
              (t) =>
                  t.status.equalsValue(SessionStatus.active) &
                  t.deletedAt.isNull(),
            ))
            .getSingleOrNull();
    return row == null ? null : _assemble(row);
  }

  @override
  Future<WorkoutSession?> findById(String id) async {
    final row = await (_db.select(
      _db.workoutSessions,
    )..where((t) => t.id.equals(id) & t.deletedAt.isNull())).getSingleOrNull();
    return row == null ? null : _assemble(row);
  }

  @override
  Future<void> discard(String sessionId) async {
    final now = _clock.nowUtc();
    await (_db.update(
      _db.workoutSessions,
    )..where((t) => t.id.equals(sessionId))).write(
      WorkoutSessionsCompanion(
        status: const Value(SessionStatus.discarded),
        restEndsAt: const Value(null),
        deletedAt: Value(now),
        updatedAt: Value(now),
      ),
    );
  }

  /// Odcisk zakończonych sesji: liczba i najnowsze `updated_at` sesji,
  /// ćwiczeń i serii. Zmienia się przy zakończeniu, edycji i usunięciu
  /// treningu z historii, ale nie przy zapisach aktywnego treningu.
  static const _completedSignature = '''
SELECT 'completed_history' AS watch_key,
  (SELECT COUNT(*) || ':' || IFNULL(MAX(updated_at), 0)
     FROM workout_sessions WHERE status = ?1 AND deleted_at IS NULL)
  || '/' ||
  (SELECT COUNT(*) || ':' || IFNULL(MAX(se.updated_at), 0)
     FROM session_exercises se
     JOIN workout_sessions ws ON ws.id = se.session_id
    WHERE ws.status = ?1 AND ws.deleted_at IS NULL AND se.deleted_at IS NULL)
  || '/' ||
  (SELECT COUNT(*) || ':' || IFNULL(MAX(ss.updated_at), 0)
     FROM session_sets ss
     JOIN session_exercises se ON se.id = ss.session_exercise_id
     JOIN workout_sessions ws ON ws.id = se.session_id
    WHERE ws.status = ?1 AND ws.deleted_at IS NULL AND se.deleted_at IS NULL
      AND ss.deleted_at IS NULL)
  AS signature''';

  @override
  Stream<List<WorkoutSession>> watchCompleted() => _db
      .customSelect(
        _completedSignature,
        variables: [Variable.withString(SessionStatus.completed.code)],
        readsFrom: {_db.workoutSessions, _db.sessionExercises, _db.sessionSets},
      )
      .watch()
      .map((rows) => rows.single.read<String>('signature'))
      .distinct()
      .asyncMap((_) => _loadCompleted());

  Future<List<WorkoutSession>> _loadCompleted() async {
    final rows =
        await (_db.select(_db.workoutSessions)
              ..where(
                (t) =>
                    t.status.equalsValue(SessionStatus.completed) &
                    t.deletedAt.isNull(),
              )
              ..orderBy([(t) => OrderingTerm.desc(t.startedAt)]))
            .get();
    return _assembleAll(rows);
  }

  @override
  Future<void> delete(String sessionId) async {
    final now = _clock.nowUtc();
    await (_db.update(
      _db.workoutSessions,
    )..where((t) => t.id.equals(sessionId) & t.deletedAt.isNull())).write(
      WorkoutSessionsCompanion(deletedAt: Value(now), updatedAt: Value(now)),
    );
  }

  @override
  Future<List<SessionSet>> lastCompletedSets(
    String exerciseId, {
    String? excludeSessionId,
  }) async {
    final latest = await _db
        .customSelect(
          'SELECT se.id AS id FROM session_exercises se '
          'JOIN workout_sessions ws ON ws.id = se.session_id '
          'WHERE se.exercise_id = ?1 AND se.deleted_at IS NULL '
          '  AND ws.deleted_at IS NULL AND ws.status = ?2 '
          '  AND ws.id IS NOT ?3 '
          // Wystąpienie bez zatwierdzonych serii nie przesłania
          // wcześniejszego wyniku.
          '  AND EXISTS (SELECT 1 FROM session_sets ss '
          '    WHERE ss.session_exercise_id = se.id '
          '      AND ss.deleted_at IS NULL AND ss.completed_at IS NOT NULL) '
          'ORDER BY ws.started_at DESC, se.position ASC LIMIT 1',
          variables: [
            Variable.withString(exerciseId),
            Variable.withString(SessionStatus.completed.code),
            Variable(excludeSessionId),
          ],
          readsFrom: {
            _db.sessionExercises,
            _db.workoutSessions,
            _db.sessionSets,
          },
        )
        .getSingleOrNull();
    if (latest == null) return const [];
    final rows =
        await (_db.select(_db.sessionSets)
              ..where(
                (t) =>
                    t.sessionExerciseId.equals(latest.read<String>('id')) &
                    t.deletedAt.isNull() &
                    t.completedAt.isNotNull(),
              )
              ..orderBy([(t) => OrderingTerm.asc(t.position)]))
            .get();
    return [for (final row in rows) _setFromRow(row)];
  }

  @override
  Future<Map<String, List<PerformedSet>>> completedSetsFor(
    Set<String> exerciseIds, {
    String? excludeSessionId,
  }) async {
    if (exerciseIds.isEmpty) return const {};
    final query =
        _db.select(_db.sessionSets).join([
          innerJoin(
            _db.sessionExercises,
            _db.sessionExercises.id.equalsExp(
              _db.sessionSets.sessionExerciseId,
            ),
          ),
          innerJoin(
            _db.workoutSessions,
            _db.workoutSessions.id.equalsExp(_db.sessionExercises.sessionId),
          ),
        ])..where(
          _db.sessionExercises.exerciseId.isIn(exerciseIds) &
              _db.sessionSets.deletedAt.isNull() &
              _db.sessionSets.completedAt.isNotNull() &
              _db.sessionExercises.deletedAt.isNull() &
              _db.workoutSessions.deletedAt.isNull() &
              _db.workoutSessions.status.equalsValue(SessionStatus.completed),
        );
    if (excludeSessionId != null) {
      query.where(_db.workoutSessions.id.equals(excludeSessionId).not());
    }
    final result = <String, List<PerformedSet>>{};
    for (final row in await query.get()) {
      final exercise = row.readTable(_db.sessionExercises);
      (result[exercise.exerciseId] ??= []).add((
        set: _setFromRow(row.readTable(_db.sessionSets)),
        loadMode: exercise.loadModeSnapshot,
      ));
    }
    return result;
  }

  @override
  Future<void> save(WorkoutSession session) => _db.transaction(() async {
    final now = _clock.nowUtc();
    if (session.isActive) {
      final otherActive =
          await (_db.select(_db.workoutSessions)..where(
                (t) =>
                    t.status.equalsValue(SessionStatus.active) &
                    t.deletedAt.isNull() &
                    t.id.equals(session.id).not(),
              ))
              .getSingleOrNull();
      if (otherActive != null) throw const ActiveSessionExistsException();
    }

    final existing = await (_db.select(
      _db.workoutSessions,
    )..where((t) => t.id.equals(session.id))).getSingleOrNull();
    await upsertIfChanged(
      _db,
      _db.workoutSessions,
      existing: existing,
      candidate: WorkoutSessionRow(
        id: session.id,
        createdAt: existing?.createdAt ?? now,
        updatedAt: existing?.updatedAt ?? now,
        deletedAt: existing?.deletedAt,
        status: session.status,
        startedAt: session.startedAt,
        endedAt: session.endedAt,
        timeZone: session.timeZone,
        localDate: session.localDate,
        templateId: session.templateId,
        templateNameSnapshot: session.templateNameSnapshot,
        title: session.title,
        notes: session.notes,
        wellbeing: session.wellbeing,
        restEndsAt: session.restEndsAt,
      ),
      touch: (row) => row.copyWith(updatedAt: now),
    );

    final existingExercises = {
      for (final row
          in await (_db.select(_db.sessionExercises)..where(
                (t) => t.sessionId.equals(session.id) & t.deletedAt.isNull(),
              ))
              .get())
        row.id: row,
    };
    for (final exercise in session.exercises) {
      final existingExercise = existingExercises.remove(exercise.id);
      await upsertIfChanged(
        _db,
        _db.sessionExercises,
        existing: existingExercise,
        candidate: _exerciseRow(
          session.id,
          exercise,
          createdAt: existingExercise?.createdAt ?? now,
          updatedAt: existingExercise?.updatedAt ?? now,
        ),
        touch: (row) => row.copyWith(updatedAt: now),
      );
      await _saveSets(exercise, now);
    }
    for (final removed in existingExercises.values) {
      await softDeleteWhere(
        _db,
        _db.sessionExercises,
        column: 'id',
        value: removed.id,
        now: now,
      );
      await softDeleteWhere(
        _db,
        _db.sessionSets,
        column: 'session_exercise_id',
        value: removed.id,
        now: now,
      );
    }
  });

  Future<void> _saveSets(SessionExercise exercise, DateTime now) async {
    final existingSets = {
      for (final row
          in await (_db.select(_db.sessionSets)..where(
                (t) =>
                    t.sessionExerciseId.equals(exercise.id) &
                    t.deletedAt.isNull(),
              ))
              .get())
        row.id: row,
    };
    for (final set in exercise.sets) {
      final existing = existingSets.remove(set.id);
      await upsertIfChanged(
        _db,
        _db.sessionSets,
        existing: existing,
        candidate: _setRow(
          exercise.id,
          set,
          createdAt: existing?.createdAt ?? now,
          updatedAt: existing?.updatedAt ?? now,
        ),
        touch: (row) => row.copyWith(updatedAt: now),
      );
    }
    for (final removed in existingSets.values) {
      await softDeleteWhere(
        _db,
        _db.sessionSets,
        column: 'id',
        value: removed.id,
        now: now,
      );
    }
  }

  Future<WorkoutSession> _assemble(WorkoutSessionRow row) async =>
      (await _assembleAll([row])).single;

  /// Składa sesje z ćwiczeniami i seriami trzema zapytaniami (w paczkach,
  /// żeby nie przekroczyć limitu parametrów SQLite), zachowując kolejność
  /// [rows].
  Future<List<WorkoutSession>> _assembleAll(
    List<WorkoutSessionRow> rows,
  ) async {
    final exerciseRows = <SessionExerciseRow>[];
    for (final chunk in rows.map((r) => r.id).slices(_chunk)) {
      exerciseRows.addAll(
        await (_db.select(_db.sessionExercises)
              ..where((t) => t.sessionId.isIn(chunk) & t.deletedAt.isNull())
              ..orderBy([(t) => OrderingTerm.asc(t.position)]))
            .get(),
      );
    }
    final setRows = <SessionSetRow>[];
    for (final chunk in exerciseRows.map((r) => r.id).slices(_chunk)) {
      setRows.addAll(
        await (_db.select(_db.sessionSets)
              ..where(
                (t) => t.sessionExerciseId.isIn(chunk) & t.deletedAt.isNull(),
              )
              ..orderBy([(t) => OrderingTerm.asc(t.position)]))
            .get(),
      );
    }
    final exercisesBySession = exerciseRows.groupListsBy((r) => r.sessionId);
    final setsByExercise = setRows.groupListsBy((r) => r.sessionExerciseId);
    return [
      for (final row in rows)
        _sessionFromRows(
          row,
          exercisesBySession[row.id] ?? const [],
          setsByExercise,
        ),
    ];
  }

  static const _chunk = 500;

  WorkoutSession _sessionFromRows(
    WorkoutSessionRow row,
    List<SessionExerciseRow> exerciseRows,
    Map<String, List<SessionSetRow>> setsByExercise,
  ) {
    return WorkoutSession(
      id: row.id,
      status: row.status,
      startedAt: row.startedAt,
      endedAt: row.endedAt,
      timeZone: row.timeZone,
      localDate: row.localDate,
      templateId: row.templateId,
      templateNameSnapshot: row.templateNameSnapshot,
      title: row.title,
      notes: row.notes,
      wellbeing: row.wellbeing,
      restEndsAt: row.restEndsAt,
      exercises: [
        for (final e in exerciseRows)
          SessionExercise(
            id: e.id,
            exerciseId: e.exerciseId,
            position: e.position,
            templateExerciseId: e.templateExerciseId,
            exerciseNameSnapshot: e.exerciseNameSnapshot,
            measurementSnapshot: Measurement(
              weight: e.measureWeightSnapshot,
              reps: e.measureRepsSnapshot,
              duration: e.measureDurationSnapshot,
              distance: e.measureDistanceSnapshot,
            ),
            loadModeSnapshot: e.loadModeSnapshot,
            weightSemanticsSnapshot: e.weightSemanticsSnapshot,
            isUnilateralSnapshot: e.isUnilateralSnapshot,
            note: e.note,
            groupId: e.groupId,
            sets: [
              for (final s in setsByExercise[e.id] ?? <SessionSetRow>[])
                _setFromRow(s),
            ],
          ),
      ],
    );
  }
}

SessionSet _setFromRow(SessionSetRow s) => SessionSet(
  id: s.id,
  position: s.position,
  setType: s.setType,
  targetKind: s.targetKind,
  targetMin: s.targetMin,
  targetMax: s.targetMax,
  targetWeightG: s.targetWeightG,
  restSeconds: s.restSeconds,
  weightG: s.weightG,
  reps: s.reps,
  durationS: s.durationS,
  distanceM: s.distanceM,
  effortScale: s.effortScale,
  effortTenths: s.effortTenths,
  side: s.side,
  completedAt: s.completedAt,
);

SessionExerciseRow _exerciseRow(
  String sessionId,
  SessionExercise exercise, {
  required DateTime createdAt,
  required DateTime updatedAt,
}) => SessionExerciseRow(
  id: exercise.id,
  createdAt: createdAt,
  updatedAt: updatedAt,
  sessionId: sessionId,
  exerciseId: exercise.exerciseId,
  position: exercise.position,
  templateExerciseId: exercise.templateExerciseId,
  exerciseNameSnapshot: exercise.exerciseNameSnapshot,
  measureWeightSnapshot: exercise.measurementSnapshot.weight,
  measureRepsSnapshot: exercise.measurementSnapshot.reps,
  measureDurationSnapshot: exercise.measurementSnapshot.duration,
  measureDistanceSnapshot: exercise.measurementSnapshot.distance,
  loadModeSnapshot: exercise.loadModeSnapshot,
  weightSemanticsSnapshot: exercise.weightSemanticsSnapshot,
  isUnilateralSnapshot: exercise.isUnilateralSnapshot,
  note: exercise.note,
  groupId: exercise.groupId,
);

SessionSetRow _setRow(
  String sessionExerciseId,
  SessionSet set, {
  required DateTime createdAt,
  required DateTime updatedAt,
}) => SessionSetRow(
  id: set.id,
  createdAt: createdAt,
  updatedAt: updatedAt,
  sessionExerciseId: sessionExerciseId,
  position: set.position,
  setType: set.setType,
  targetKind: set.targetKind,
  targetMin: set.targetMin,
  targetMax: set.targetMax,
  targetWeightG: set.targetWeightG,
  restSeconds: set.restSeconds,
  weightG: set.weightG,
  reps: set.reps,
  durationS: set.durationS,
  distanceM: set.distanceM,
  effortScale: set.effortScale,
  effortTenths: set.effortTenths,
  side: set.side,
  completedAt: set.completedAt,
);
