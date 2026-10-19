import 'dart:convert';

import '../../../core/database/app_database.dart';
import '../../../core/database/setting_keys.dart';
import '../../../core/domain/clock.dart';
import '../domain/exercise.dart';
import '../domain/seed_sync.dart';
import 'drift_exercise_repository.dart';
import 'seed_catalog.dart';

/// Wynik zastosowania seeda.
final class SeedResult {
  const SeedResult({
    required this.applied,
    required this.inserted,
    required this.updated,
    required this.skippedUserModified,
  });

  static const upToDate = SeedResult(
    applied: false,
    inserted: 0,
    updated: 0,
    skippedUserModified: 0,
  );

  /// Czy wersja seeda była nowsza niż zapisana i została zastosowana.
  final bool applied;
  final int inserted;
  final int updated;
  final int skippedUserModified;
}

/// Synchronizuje wbudowaną bibliotekę z bazą w jednej transakcji.
final class ExerciseSeeder {
  ExerciseSeeder(this._db, this._clock);

  final AppDatabase _db;
  final Clock _clock;

  Future<SeedResult> apply(SeedCatalog catalog) => _db.transaction(() async {
    final stored = await _storedVersion();
    if (catalog.seedVersion <= stored) return SeedResult.upToDate;

    final rows = await (_db.select(
      _db.exercises,
    )..where((t) => t.source.equalsValue(ExerciseSource.builtin))).get();
    final rowsById = {for (final r in rows) r.id: r};
    final plan = planSeedSync(
      existing: rows.map(exerciseFromRow),
      seed: catalog.exercises,
    );

    final now = _clock.nowUtc();
    for (final exercise in plan.inserts) {
      await _db
          .into(_db.exercises)
          .insert(exerciseToRow(exercise, createdAt: now, updatedAt: now));
    }
    for (final exercise in plan.updates) {
      final row = rowsById[exercise.id]!;
      await _db
          .into(_db.exercises)
          .insertOnConflictUpdate(
            exerciseToRow(
              exercise,
              createdAt: row.createdAt,
              updatedAt: now,
              deletedAt: row.deletedAt,
            ),
          );
    }
    await _db
        .into(_db.settings)
        .insertOnConflictUpdate(
          SettingsCompanion.insert(
            key: SettingKeys.seedVersion,
            value: jsonEncode(catalog.seedVersion),
            updatedAt: now,
          ),
        );
    return SeedResult(
      applied: true,
      inserted: plan.inserts.length,
      updated: plan.updates.length,
      skippedUserModified: plan.skippedUserModified.length,
    );
  });

  Future<int> _storedVersion() async {
    final row = await (_db.select(
      _db.settings,
    )..where((t) => t.key.equals(SettingKeys.seedVersion))).getSingleOrNull();
    if (row == null) return 0;
    final value = jsonDecode(row.value);
    return value is int ? value : 0;
  }
}
