import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reptrack/app/app.dart';
import 'package:reptrack/core/database/app_database.dart';
import 'package:reptrack/core/database/database_providers.dart';
import 'package:reptrack/features/exercises/data/exercise_seeder.dart';
import 'package:reptrack/features/exercises/data/seed_catalog.dart';

import 'test_database.dart';

/// Uruchamia całą aplikację po polsku na bazie testowej, opcjonalnie
/// z wbudowaną biblioteką ćwiczeń.
Future<AppDatabase> pumpRepTrack(
  WidgetTester tester, {
  bool seed = true,
}) async {
  tester.platformDispatcher.localeTestValue = const Locale('pl', 'PL');
  tester.platformDispatcher.localesTestValue = const [Locale('pl', 'PL')];
  addTearDown(tester.platformDispatcher.clearAllTestValues);

  final db = widgetTestDatabase();
  if (seed) {
    await tester.runAsync(() async {
      final catalog = parseSeedCatalog(
        await File(seedAssetPath).readAsString(),
      );
      await ExerciseSeeder(db, testClock()).apply(catalog);
    });
  }
  await tester.pumpWidget(
    ProviderScope(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
      child: const RepTrackApp(),
    ),
  );
  await tester.pumpAndSettle();
  return db;
}

/// Zamyka drzewo widżetów przed bazą, żeby strumienie Drift się zakończyły.
Future<void> closeRepTrack(WidgetTester tester, AppDatabase db) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.runAsync(db.close);
}

/// Przycisk zakładki dolnej nawigacji.
Finder navTab(String label) =>
    find.descendant(of: find.byType(NavigationBar), matching: find.text(label));
