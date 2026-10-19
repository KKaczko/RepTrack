import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:reptrack/core/database/app_database.dart';
import 'package:reptrack/core/domain/clock.dart';
import 'package:reptrack/features/exercises/domain/exercise.dart';

/// Prawdziwa baza Drift w pamięci, z tymi samymi ustawieniami połączenia
/// co w aplikacji.
AppDatabase memoryDatabase() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  return AppDatabase(
    NativeDatabase.memory(setup: AppDatabase.configureConnection),
  );
}

/// Baza w pamięci do testów widżetów. Strumienie Drift zamykają się
/// synchronicznie, bo fałszywy zegar `testWidgets` nie uruchamia timerów,
/// którymi Drift domyślnie odracza ich zamknięcie.
AppDatabase widgetTestDatabase() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  return AppDatabase(
    DatabaseConnection(
      NativeDatabase.memory(setup: AppDatabase.configureConnection),
      closeStreamsSynchronously: true,
    ),
  );
}

/// Baza w pliku, do testów trwałości (zamknięcie i ponowne otwarcie).
AppDatabase fileDatabase(File file) {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  return AppDatabase(
    NativeDatabase(file, setup: AppDatabase.configureConnection),
  );
}

FixedClock testClock() => FixedClock(DateTime.utc(2026, 10, 19, 18));

Exercise testExercise(
  String id, {
  String? name,
  Measurement measurement = Measurement.weightAndReps,
}) => Exercise(
  id: id,
  name: name ?? 'Ćwiczenie $id',
  aliases: const ['alias'],
  primaryMuscles: const [MuscleGroup.chest],
  secondaryMuscles: const [MuscleGroup.triceps, MuscleGroup.shoulders],
  equipment: Equipment.barbell,
  measurement: measurement,
);
