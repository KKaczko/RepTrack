import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/database/app_database.dart';
import '../core/database/database_providers.dart';
import '../core/domain/clock.dart';
import '../core/domain/local_date.dart';
import '../core/platform/rest_notifications.dart';
import '../features/exercises/data/exercise_seeder.dart';
import '../features/exercises/data/seed_catalog.dart';
import '../features/workout/data/drift_workout_repository.dart';
import '../features/workout/domain/set_hints.dart';

/// Przygotowanie aplikacji przed pierwszą klatką: strefy czasowe, licencje
/// zasobów, baza danych i wbudowana biblioteka ćwiczeń.
Future<ProviderContainer> bootstrap() async {
  ensureTimeZonesLoaded();
  LicenseRegistry.addLicense(_assetLicenses);
  final db = AppDatabase.open();
  await seedExerciseLibrary(db, rootBundle);
  final notifications = await _restNotifications();
  await restoreRestNotification(db, notifications);
  return ProviderContainer(
    overrides: [
      appDatabaseProvider.overrideWithValue(db),
      restNotificationsProvider.overrideWithValue(notifications),
    ],
  );
}

/// Przywraca powiadomienie trwającej przerwy po restarcie aplikacji (np. po
/// wymuszonym zamknięciu system usuwa powiadomienia i alarmy aplikacji).
Future<void> restoreRestNotification(
  AppDatabase db,
  RestNotifications notifications,
) async {
  try {
    final session = await DriftWorkoutRepository(
      db,
      const SystemClock(),
    ).findActive();
    final endsAt = session?.restEndsAt;
    if (session == null ||
        endsAt == null ||
        !endsAt.isAfter(DateTime.now().toUtc())) {
      return;
    }
    await notifications.startRest(
      endsAt: endsAt,
      nextName: nextExerciseToDo(session, null)?.exerciseNameSnapshot ?? '',
    );
  } on Object catch (error, stack) {
    FlutterError.reportError(
      FlutterErrorDetails(exception: error, stack: stack, library: 'reptrack'),
    );
  }
}

/// Powiadomienia przerwy; gdy inicjalizacja się nie uda, timer działa tylko
/// w aplikacji.
Future<RestNotifications> _restNotifications() async {
  final notifications = LocalRestNotifications();
  try {
    await notifications.initialize();
    return notifications;
  } on Object catch (error, stack) {
    FlutterError.reportError(
      FlutterErrorDetails(exception: error, stack: stack, library: 'reptrack'),
    );
    return const NoopRestNotifications();
  }
}

/// Synchronizuje wbudowaną bibliotekę. Błąd seeda nie blokuje startu
/// aplikacji: dane użytkownika i jego własne ćwiczenia pozostają dostępne.
Future<void> seedExerciseLibrary(AppDatabase db, AssetBundle bundle) async {
  try {
    final catalog = parseSeedCatalog(await bundle.loadString(seedAssetPath));
    await ExerciseSeeder(db, const SystemClock()).apply(catalog);
  } on Object catch (error, stack) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stack,
        library: 'reptrack seed',
        context: ErrorDescription('podczas synchronizacji biblioteki ćwiczeń'),
      ),
    );
  }
}

Stream<LicenseEntry> _assetLicenses() async* {
  final inter = await rootBundle.loadString('assets/fonts/Inter-OFL.txt');
  yield LicenseEntryWithLineBreaks(const ['Inter (font)'], inter);
  final exercises = await rootBundle.loadString(
    'assets/seed/free-exercise-db-LICENSE.txt',
  );
  yield LicenseEntryWithLineBreaks(const [
    'free-exercise-db (biblioteka ćwiczeń)',
  ], exercises);
}
