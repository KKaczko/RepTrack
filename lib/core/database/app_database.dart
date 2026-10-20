import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/common.dart' show CommonDatabase;

import '../../features/exercises/domain/exercise.dart';
import '../../features/plan/domain/plan.dart';
import '../../features/workout/domain/workout_session.dart';
import '../domain/local_date.dart';
import '../domain/training.dart';
import 'app_database.steps.dart';
import 'converters.dart';
import 'tables.dart';

part 'app_database.g.dart';

/// Lokalna baza RepTrack. Wersja schematu jest niezależna od wersji formatu
/// backupu (ADR 0008). Każda zmiana schematu to migracja z testem na zrzutach
/// z `drift_schemas/`.
@DriftDatabase(
  tables: [
    Exercises,
    Templates,
    TemplateExercises,
    TemplateSets,
    WorkoutSessions,
    SessionExercises,
    SessionSets,
    Settings,
    WeeklyPlans,
    WeeklyPlanDays,
    PlannedDays,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  /// Baza w pliku `reptrack.sqlite` w katalogu wsparcia aplikacji (files/),
  /// objętym przez Android Auto Backup.
  factory AppDatabase.open() => AppDatabase(
    driftDatabase(
      name: 'reptrack',
      native: const DriftNativeOptions(
        databaseDirectory: getApplicationSupportDirectory,
        setup: configureConnection,
      ),
    ),
  );

  /// Ustawienia połączenia: tryb WAL i klucze obce.
  static void configureConnection(CommonDatabase db) {
    db
      ..execute('PRAGMA journal_mode = WAL;')
      ..execute('PRAGMA foreign_keys = ON;');
  }

  /// Przenosi zmiany z pliku WAL do bazy i opróżnia WAL. Wywoływane przy
  /// przejściu aplikacji w tło, żeby Android Auto Backup skopiował spójny
  /// plik bazy (ADR 0008).
  Future<void> checkpoint() async {
    try {
      await customStatement('PRAGMA wal_checkpoint(TRUNCATE)');
    } on Object {
      // Zajęta baza: checkpoint wykona się przy następnej okazji.
    }
  }

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    // Kroki z app_database.steps.dart (`dart run drift_dev make-migrations`).
    onUpgrade: stepByStep(
      // v2: plan treningów (ADR 0015). Istniejące tabele bez zmian.
      from1To2: (m, schema) async {
        await m.createTable(schema.weeklyPlans);
        await m.createTable(schema.weeklyPlanDays);
        await m.createTable(schema.plannedDays);
        await m.createIndex(schema.idxWeeklyPlanDaysPlan);
        await m.createIndex(schema.idxPlannedDaysDate);
      },
    ),
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
