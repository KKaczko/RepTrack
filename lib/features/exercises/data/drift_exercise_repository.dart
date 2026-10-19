import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../core/domain/clock.dart';
import '../../../core/domain/text_normalize.dart';
import '../domain/exercise.dart';
import '../domain/exercise_repository.dart';

final class DriftExerciseRepository implements ExerciseRepository {
  DriftExerciseRepository(this._db, this._clock);

  final AppDatabase _db;
  final Clock _clock;

  @override
  Stream<List<Exercise>> watchAll({bool includeArchived = false}) =>
      _query(includeArchived: includeArchived).watch().map(_sorted);

  @override
  Future<List<Exercise>> findAll({bool includeArchived = false}) async =>
      _sorted(await _query(includeArchived: includeArchived).get());

  SimpleSelectStatement<$ExercisesTable, ExerciseRow> _query({
    required bool includeArchived,
  }) {
    final query = _db.select(_db.exercises)..where((t) => t.deletedAt.isNull());
    if (!includeArchived) {
      query.where((t) => t.archivedAt.isNull());
    }
    return query;
  }

  /// Sortowanie po nazwie bez diakrytyków: „Ławka” obok „Lina”, nie po „Z”.
  static List<Exercise> _sorted(List<ExerciseRow> rows) =>
      rows.map(exerciseFromRow).toList()..sort(
        (a, b) =>
            normalizeForSearch(a.name).compareTo(normalizeForSearch(b.name)),
      );

  @override
  Future<Exercise?> findById(String id) async {
    final row = await _findRow(id);
    return row == null || row.deletedAt != null ? null : exerciseFromRow(row);
  }

  @override
  Future<void> save(Exercise exercise) {
    if (!exercise.measurement.isValid) {
      throw ArgumentError.value(
        exercise.measurement,
        'measurement',
        'Ćwiczenie musi mierzyć co najmniej jedno pole',
      );
    }
    return _db.transaction(() async {
      final existing = await _findRow(exercise.id);
      final now = _clock.nowUtc();
      await _db
          .into(_db.exercises)
          .insertOnConflictUpdate(
            exerciseToRow(
              exercise,
              createdAt: existing?.createdAt ?? now,
              updatedAt: now,
              deletedAt: existing?.deletedAt,
            ),
          );
    });
  }

  @override
  Future<void> setArchived(String id, {required bool archived}) async {
    final now = _clock.nowUtc();
    await (_db.update(_db.exercises)..where((t) => t.id.equals(id))).write(
      ExercisesCompanion(
        archivedAt: Value(archived ? now : null),
        updatedAt: Value(now),
      ),
    );
  }

  @override
  Future<bool> isInUse(String id) async {
    final row = await _db
        .customSelect(
          'SELECT EXISTS ('
          '  SELECT 1 FROM template_exercises te'
          '  JOIN templates t ON t.id = te.template_id'
          '  WHERE te.exercise_id = ?1 AND te.deleted_at IS NULL'
          '    AND t.deleted_at IS NULL'
          ') OR EXISTS ('
          '  SELECT 1 FROM session_exercises se'
          '  JOIN workout_sessions s ON s.id = se.session_id'
          '  WHERE se.exercise_id = ?1 AND se.deleted_at IS NULL'
          '    AND s.deleted_at IS NULL'
          ') AS in_use',
          variables: [Variable.withString(id)],
          readsFrom: {
            _db.templateExercises,
            _db.templates,
            _db.sessionExercises,
            _db.workoutSessions,
          },
        )
        .getSingle();
    return row.read<bool>('in_use');
  }

  @override
  Future<void> delete(String id) => _db.transaction(() async {
    if (await isInUse(id)) {
      throw ExerciseInUseException(id);
    }
    final now = _clock.nowUtc();
    await (_db.update(_db.exercises)..where((t) => t.id.equals(id))).write(
      ExercisesCompanion(deletedAt: Value(now), updatedAt: Value(now)),
    );
  });

  Future<ExerciseRow?> _findRow(String id) => (_db.select(
    _db.exercises,
  )..where((t) => t.id.equals(id))).getSingleOrNull();
}

Exercise exerciseFromRow(ExerciseRow row) => Exercise(
  id: row.id,
  name: row.name,
  aliases: row.aliases,
  primaryMuscles: row.primaryMuscles,
  secondaryMuscles: row.secondaryMuscles,
  equipment: row.equipment,
  category: row.category,
  mechanic: row.mechanic,
  force: row.force,
  instructions: row.instructions,
  measurement: Measurement(
    weight: row.measureWeight,
    reps: row.measureReps,
    duration: row.measureDuration,
    distance: row.measureDistance,
  ),
  loadMode: row.loadMode,
  weightSemantics: row.weightSemantics,
  isUnilateral: row.isUnilateral,
  imageRef: row.imageRef,
  source: row.source,
  originRef: row.originRef,
  license: row.license,
  licenseAuthor: row.licenseAuthor,
  seedVersion: row.seedVersion,
  userModified: row.userModified,
  archivedAt: row.archivedAt,
);

ExerciseRow exerciseToRow(
  Exercise exercise, {
  required DateTime createdAt,
  required DateTime updatedAt,
  DateTime? deletedAt,
}) => ExerciseRow(
  id: exercise.id,
  createdAt: createdAt,
  updatedAt: updatedAt,
  deletedAt: deletedAt,
  name: exercise.name,
  aliases: exercise.aliases,
  searchText: exercise.searchText,
  primaryMuscles: exercise.primaryMuscles,
  secondaryMuscles: exercise.secondaryMuscles,
  equipment: exercise.equipment,
  category: exercise.category,
  mechanic: exercise.mechanic,
  force: exercise.force,
  instructions: exercise.instructions,
  measureWeight: exercise.measurement.weight,
  measureReps: exercise.measurement.reps,
  measureDuration: exercise.measurement.duration,
  measureDistance: exercise.measurement.distance,
  loadMode: exercise.loadMode,
  weightSemantics: exercise.weightSemantics,
  isUnilateral: exercise.isUnilateral,
  imageRef: exercise.imageRef,
  source: exercise.source,
  originRef: exercise.originRef,
  license: exercise.license,
  licenseAuthor: exercise.licenseAuthor,
  seedVersion: exercise.seedVersion,
  userModified: exercise.userModified,
  archivedAt: exercise.archivedAt,
);
