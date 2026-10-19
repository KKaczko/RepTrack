import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/common.dart' show CommonDatabase;

import '../../features/exercises/domain/exercise.dart';
import '../../features/workout/domain/workout_session.dart';
import '../domain/local_date.dart';
import '../domain/training.dart';
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

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      // Kolejne wersje: stepByStep z app_database.steps.dart
      // (`dart run drift_dev make-migrations`).
      throw UnsupportedError('Brak migracji z wersji $from do $to');
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
