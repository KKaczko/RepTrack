import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/upsert.dart';
import '../../../core/database/watch_tables.dart';
import '../../../core/domain/clock.dart';
import '../../../core/domain/ids.dart';
import '../domain/substitute_repository.dart';
import '../domain/substitutes.dart';

final class DriftSubstituteRepository implements SubstituteRepository {
  DriftSubstituteRepository(this._db, this._clock, this._ids);

  final AppDatabase _db;
  final Clock _clock;
  final IdGenerator _ids;

  @override
  Stream<List<SubstitutePin>> watch() => watchTables(_db, 'substitutes', {
    _db.exerciseSubstitutes,
  }).asyncMap((_) => _load());

  Future<List<SubstitutePin>> _load() async {
    final rows =
        await (_db.select(_db.exerciseSubstitutes)
              ..where((t) => t.deletedAt.isNull())
              ..orderBy([
                (t) => OrderingTerm.asc(t.position),
                (t) => OrderingTerm.asc(t.createdAt),
              ]))
            .get();
    return [
      for (final row in rows)
        (exerciseId: row.exerciseId, substituteId: row.substituteId),
    ];
  }

  /// Nieusunięte wiersze pary w którąkolwiek stronę.
  Future<List<ExerciseSubstituteRow>> _pair(String a, String b) =>
      (_db.select(_db.exerciseSubstitutes)..where(
            (t) =>
                t.deletedAt.isNull() &
                ((t.exerciseId.equals(a) & t.substituteId.equals(b)) |
                    (t.exerciseId.equals(b) & t.substituteId.equals(a))),
          ))
          .get();

  @override
  Future<void> pin(String exerciseId, String substituteId) =>
      _db.transaction(() async {
        if (exerciseId == substituteId) return;
        if ((await _pair(exerciseId, substituteId)).isNotEmpty) return;
        final last =
            await (_db.selectOnly(_db.exerciseSubstitutes)
                  ..addColumns([_db.exerciseSubstitutes.position.max()]))
                .map((r) => r.read(_db.exerciseSubstitutes.position.max()))
                .getSingle();
        final now = _clock.nowUtc();
        await _db
            .into(_db.exerciseSubstitutes)
            .insert(
              ExerciseSubstituteRow(
                id: _ids.newId(),
                createdAt: now,
                updatedAt: now,
                exerciseId: exerciseId,
                substituteId: substituteId,
                position: (last ?? -1) + 1,
              ),
            );
      });

  @override
  Future<void> unpin(String exerciseId, String substituteId) =>
      _db.transaction(() async {
        final now = _clock.nowUtc();
        for (final row in await _pair(exerciseId, substituteId)) {
          await softDeleteWhere(
            _db,
            _db.exerciseSubstitutes,
            column: 'id',
            value: row.id,
            now: now,
          );
        }
      });
}
