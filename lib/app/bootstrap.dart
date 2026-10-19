import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/database/app_database.dart';
import '../core/database/database_providers.dart';
import '../core/domain/clock.dart';
import '../core/domain/local_date.dart';
import '../features/exercises/data/exercise_seeder.dart';
import '../features/exercises/data/seed_catalog.dart';

/// Przygotowanie aplikacji przed pierwszą klatką: strefy czasowe, licencje
/// zasobów, baza danych i wbudowana biblioteka ćwiczeń.
Future<ProviderContainer> bootstrap() async {
  ensureTimeZonesLoaded();
  LicenseRegistry.addLicense(_assetLicenses);
  final db = AppDatabase.open();
  await seedExerciseLibrary(db, rootBundle);
  return ProviderContainer(
    overrides: [appDatabaseProvider.overrideWithValue(db)],
  );
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
