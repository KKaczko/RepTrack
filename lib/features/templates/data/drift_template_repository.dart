import 'package:collection/collection.dart';
import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/upsert.dart';
import '../../../core/database/watch_tables.dart';
import '../../../core/domain/clock.dart';
import '../../../core/domain/text_normalize.dart';
import '../domain/template.dart';
import '../domain/template_repository.dart';

final class DriftTemplateRepository implements TemplateRepository {
  DriftTemplateRepository(this._db, this._clock);

  final AppDatabase _db;
  final Clock _clock;

  @override
  Stream<List<Template>> watchAll({bool includeArchived = false}) =>
      watchTables(_db, 'templates', {
        _db.templates,
        _db.templateExercises,
        _db.templateSets,
      }).asyncMap((_) => _loadAll(includeArchived: includeArchived));

  @override
  Future<Template?> findById(String id) async {
    final row = await (_db.select(
      _db.templates,
    )..where((t) => t.id.equals(id) & t.deletedAt.isNull())).getSingleOrNull();
    if (row == null) return null;
    return (await _assemble([row])).single;
  }

  @override
  Future<void> save(Template template) => _db.transaction(() async {
    final now = _clock.nowUtc();
    final existingTemplate = await (_db.select(
      _db.templates,
    )..where((t) => t.id.equals(template.id))).getSingleOrNull();

    await upsertIfChanged(
      _db,
      _db.templates,
      existing: existingTemplate,
      candidate: TemplateRow(
        id: template.id,
        createdAt: existingTemplate?.createdAt ?? now,
        updatedAt: existingTemplate?.updatedAt ?? now,
        deletedAt: existingTemplate?.deletedAt,
        name: template.name,
        description: template.description,
        archivedAt: template.archivedAt,
      ),
      touch: (row) => row.copyWith(updatedAt: now),
    );

    final existingExercises = {
      for (final row
          in await (_db.select(_db.templateExercises)..where(
                (t) => t.templateId.equals(template.id) & t.deletedAt.isNull(),
              ))
              .get())
        row.id: row,
    };

    for (final exercise in template.exercises) {
      final existing = existingExercises.remove(exercise.id);
      await upsertIfChanged(
        _db,
        _db.templateExercises,
        existing: existing,
        candidate: _exerciseRow(
          template.id,
          exercise,
          createdAt: existing?.createdAt ?? now,
          updatedAt: existing?.updatedAt ?? now,
        ),
        touch: (row) => row.copyWith(updatedAt: now),
      );
      await _saveSets(exercise, now);
    }

    // Ćwiczenia usunięte z szablonu: miękkie usunięcie wraz z seriami.
    for (final removed in existingExercises.values) {
      await _softDeleteExercise(removed.id, now);
    }
  });

  @override
  Future<void> setArchived(String id, {required bool archived}) async {
    final now = _clock.nowUtc();
    await (_db.update(_db.templates)..where((t) => t.id.equals(id))).write(
      TemplatesCompanion(
        archivedAt: Value(archived ? now : null),
        updatedAt: Value(now),
      ),
    );
  }

  @override
  Future<void> delete(String id) async {
    final now = _clock.nowUtc();
    await (_db.update(_db.templates)..where((t) => t.id.equals(id))).write(
      TemplatesCompanion(deletedAt: Value(now), updatedAt: Value(now)),
    );
  }

  Future<void> _saveSets(TemplateExercise exercise, DateTime now) async {
    final existingSets = {
      for (final row
          in await (_db.select(_db.templateSets)..where(
                (t) =>
                    t.templateExerciseId.equals(exercise.id) &
                    t.deletedAt.isNull(),
              ))
              .get())
        row.id: row,
    };
    for (final set in exercise.sets) {
      final existing = existingSets.remove(set.id);
      await upsertIfChanged(
        _db,
        _db.templateSets,
        existing: existing,
        candidate: TemplateSetRow(
          id: set.id,
          createdAt: existing?.createdAt ?? now,
          updatedAt: existing?.updatedAt ?? now,
          templateExerciseId: exercise.id,
          position: set.position,
          setType: set.setType,
          targetMin: set.targetMin,
          targetMax: set.targetMax,
          targetWeightG: set.targetWeightG,
          restSeconds: set.restSeconds,
        ),
        touch: (row) => row.copyWith(updatedAt: now),
      );
    }
    for (final removed in existingSets.values) {
      await softDeleteWhere(
        _db,
        _db.templateSets,
        column: 'id',
        value: removed.id,
        now: now,
      );
    }
  }

  Future<void> _softDeleteExercise(String id, DateTime now) async {
    await softDeleteWhere(
      _db,
      _db.templateExercises,
      column: 'id',
      value: id,
      now: now,
    );
    await softDeleteWhere(
      _db,
      _db.templateSets,
      column: 'template_exercise_id',
      value: id,
      now: now,
    );
  }

  Future<List<Template>> _loadAll({required bool includeArchived}) async {
    final query = _db.select(_db.templates)..where((t) => t.deletedAt.isNull());
    if (!includeArchived) {
      query.where((t) => t.archivedAt.isNull());
    }
    final templates = await _assemble(await query.get());
    return templates.sortedBy((t) => normalizeForSearch(t.name));
  }

  Future<List<Template>> _assemble(List<TemplateRow> rows) async {
    if (rows.isEmpty) return const [];
    final exerciseRows =
        await (_db.select(_db.templateExercises)
              ..where(
                (t) =>
                    t.templateId.isIn(rows.map((r) => r.id)) &
                    t.deletedAt.isNull(),
              )
              ..orderBy([(t) => OrderingTerm.asc(t.position)]))
            .get();
    final setRows =
        await (_db.select(_db.templateSets)
              ..where(
                (t) =>
                    t.templateExerciseId.isIn(exerciseRows.map((r) => r.id)) &
                    t.deletedAt.isNull(),
              )
              ..orderBy([(t) => OrderingTerm.asc(t.position)]))
            .get();
    final setsByExercise = setRows.groupListsBy((r) => r.templateExerciseId);
    final exercisesByTemplate = exerciseRows.groupListsBy((r) => r.templateId);

    return [
      for (final row in rows)
        Template(
          id: row.id,
          name: row.name,
          description: row.description,
          archivedAt: row.archivedAt,
          exercises: [
            for (final e
                in exercisesByTemplate[row.id] ?? <TemplateExerciseRow>[])
              TemplateExercise(
                id: e.id,
                exerciseId: e.exerciseId,
                position: e.position,
                targetKind: e.targetKind,
                targetMin: e.targetMin,
                targetMax: e.targetMax,
                targetWeightG: e.targetWeightG,
                restSeconds: e.restSeconds,
                defaultSetType: e.defaultSetType,
                note: e.note,
                groupId: e.groupId,
                sets: [
                  for (final s in setsByExercise[e.id] ?? <TemplateSetRow>[])
                    TemplateSet(
                      id: s.id,
                      position: s.position,
                      setType: s.setType,
                      targetMin: s.targetMin,
                      targetMax: s.targetMax,
                      targetWeightG: s.targetWeightG,
                      restSeconds: s.restSeconds,
                    ),
                ],
              ),
          ],
        ),
    ];
  }
}

TemplateExerciseRow _exerciseRow(
  String templateId,
  TemplateExercise exercise, {
  required DateTime createdAt,
  required DateTime updatedAt,
}) => TemplateExerciseRow(
  id: exercise.id,
  createdAt: createdAt,
  updatedAt: updatedAt,
  templateId: templateId,
  exerciseId: exercise.exerciseId,
  position: exercise.position,
  targetKind: exercise.targetKind,
  targetMin: exercise.targetMin,
  targetMax: exercise.targetMax,
  targetWeightG: exercise.targetWeightG,
  restSeconds: exercise.restSeconds,
  defaultSetType: exercise.defaultSetType,
  note: exercise.note,
  groupId: exercise.groupId,
);
