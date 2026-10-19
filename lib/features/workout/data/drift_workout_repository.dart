import 'package:collection/collection.dart';
import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/upsert.dart';
import '../../../core/domain/clock.dart';
import '../../exercises/domain/exercise.dart';
import '../domain/workout_repository.dart';
import '../domain/workout_session.dart';

final class DriftWorkoutRepository implements WorkoutRepository {
  DriftWorkoutRepository(this._db, this._clock);

  final AppDatabase _db;
  final Clock _clock;

  @override
  Stream<WorkoutSession?> watchActive() => _db
      .customSelect(
        'SELECT 1',
        readsFrom: {_db.workoutSessions, _db.sessionExercises, _db.sessionSets},
      )
      .watch()
      .asyncMap((_) => findActive());

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

  Future<WorkoutSession> _assemble(WorkoutSessionRow row) async {
    final exerciseRows =
        await (_db.select(_db.sessionExercises)
              ..where((t) => t.sessionId.equals(row.id) & t.deletedAt.isNull())
              ..orderBy([(t) => OrderingTerm.asc(t.position)]))
            .get();
    final setRows =
        await (_db.select(_db.sessionSets)
              ..where(
                (t) =>
                    t.sessionExerciseId.isIn(exerciseRows.map((r) => r.id)) &
                    t.deletedAt.isNull(),
              )
              ..orderBy([(t) => OrderingTerm.asc(t.position)]))
            .get();
    final setsByExercise = setRows.groupListsBy((r) => r.sessionExerciseId);

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
                SessionSet(
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
                ),
            ],
          ),
      ],
    );
  }
}

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
