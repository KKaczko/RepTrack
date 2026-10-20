import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:reptrack/app/app.dart';
import 'package:reptrack/core/database/app_database.dart';
import 'package:reptrack/core/database/database_providers.dart';
import 'package:reptrack/core/domain/clock.dart';
import 'package:reptrack/core/platform/device_services.dart';
import 'package:reptrack/core/platform/file_exchange.dart';
import 'package:reptrack/core/platform/rest_notifications.dart';
import 'package:reptrack/features/assistant/data/assistant_providers.dart';
import 'package:reptrack/features/exercises/data/exercise_seeder.dart';
import 'package:reptrack/features/exercises/data/seed_catalog.dart';

import 'fake_devices.dart';
import 'test_database.dart';

/// Uruchamia całą aplikację po polsku na bazie testowej, opcjonalnie
/// z wbudowaną biblioteką ćwiczeń. Podanie [db] uruchamia aplikację ponownie
/// na istniejącej bazie (symulacja restartu). Usługi urządzenia są
/// podmienione na atrapy.
Future<AppDatabase> pumpRepTrack(
  WidgetTester tester, {
  bool seed = true,
  AppDatabase? db,
  Clock? clock,
  FakeRestNotifications? notifications,
  FakeScreenAwake? awake,
  FakeFileExchange? files,
  FakeAssistantClient? assistant,
  List<Override> overrides = const [],
}) async {
  tester.platformDispatcher.localeTestValue = const Locale('pl', 'PL');
  tester.platformDispatcher.localesTestValue = const [Locale('pl', 'PL')];
  addTearDown(tester.platformDispatcher.clearAllTestValues);

  final reopened = db != null;
  final database = db ?? widgetTestDatabase();
  if (seed && !reopened) {
    await tester.runAsync(() async {
      final catalog = parseSeedCatalog(
        await File(seedAssetPath).readAsString(),
      );
      await ExerciseSeeder(database, testClock()).apply(catalog);
    });
  }
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        if (clock != null) clockProvider.overrideWithValue(clock),
        deviceTimeZoneProvider.overrideWithValue(const FixedTimeZone()),
        screenAwakeProvider.overrideWithValue(awake ?? FakeScreenAwake()),
        restNotificationsProvider.overrideWithValue(
          notifications ?? FakeRestNotifications(),
        ),
        fileExchangeProvider.overrideWithValue(files ?? FakeFileExchange()),
        assistantClientProvider.overrideWithValue(
          assistant ?? FakeAssistantClient(),
        ),
        ...overrides,
      ],
      child: const RepTrackApp(),
    ),
  );
  await tester.pumpAndSettle();
  return database;
}

/// Zamyka drzewo widżetów przed bazą, żeby strumienie Drift się zakończyły.
Future<void> closeRepTrack(WidgetTester tester, AppDatabase db) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.runAsync(db.close);
}

/// Przycisk zakładki dolnej nawigacji.
Finder navTab(String label) =>
    find.descendant(of: find.byType(NavigationBar), matching: find.text(label));
