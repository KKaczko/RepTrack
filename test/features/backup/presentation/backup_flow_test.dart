import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reptrack/core/database/app_database.dart';
import 'package:reptrack/features/backup/data/backup_providers.dart';
import 'package:reptrack/features/backup/data/backup_store.dart';
import 'package:reptrack/features/backup/domain/backup_validation.dart';
import 'package:reptrack/features/exercises/data/drift_exercise_repository.dart';
import 'package:reptrack/features/templates/data/drift_template_repository.dart';
import 'package:reptrack/features/workout/data/drift_workout_repository.dart';
import 'package:reptrack/features/workout/domain/workout_session.dart';

import '../../../support/app_harness.dart';
import '../../../support/fake_devices.dart';
import '../../../support/test_database.dart';
import '../../../support/workout_fixtures.dart';

/// Aplikacja 360 × 800 dp z jednym zakończonym treningiem, otwarta na
/// ekranie „Kopia i eksport”.
Future<AppDatabase> _openBackup(
  WidgetTester tester, {
  required FakeFileExchange files,
  List<String>? safetyCopies,
  FakeRestNotifications? notifications,
  double height = 800,
}) async {
  tester.view.physicalSize = Size(1080, height * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final db = widgetTestDatabase();
  await tester.runAsync(() async {
    for (final e in catalog.values) {
      await DriftExerciseRepository(db, testClock()).save(e);
    }
    await DriftTemplateRepository(db, testClock()).save(pushTemplate());
    await DriftWorkoutRepository(
      db,
      testClock(),
    ).save(finishedPush('a', DateTime.utc(2026, 10, 12, 16), [(80000, 10)]));
  });
  await pumpRepTrack(
    tester,
    db: db,
    clock: testClock(),
    files: files,
    notifications: notifications,
    overrides: [
      safetyCopyWriterProvider.overrideWithValue(
        (json) async => safetyCopies?.add(json),
      ),
    ],
  );
  await tester.tap(find.byTooltip('Otwórz ustawienia'));
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(find.text('Kopia i eksport'), 200);
  await tester.ensureVisible(find.text('Kopia i eksport'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Kopia i eksport'));
  await tester.pumpAndSettle();
  return db;
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<int> _sessionCount(WidgetTester tester, AppDatabase db) async =>
    (await tester.runAsync(() => db.select(db.workoutSessions).get()))!.length;

void main() {
  testWidgets('zapis kopii do pliku', (tester) async {
    final files = FakeFileExchange();
    final db = await _openBackup(tester, files: files);

    await _tap(tester, find.text('Zapisz kopię do pliku'));

    expect(find.text('Kopia zapisana'), findsOneWidget);
    final file = files.saved.single;
    expect(
      file.fileName,
      matches(RegExp(r'^reptrack-kopia-\d{4}-\d\d-\d\d\.json$')),
    );
    expect(file.mimeType, 'application/json');
    final backup = readBackup(file.content);
    expect(backup['workoutSessions'], hasLength(1));

    await closeRepTrack(tester, db);
  });

  testWidgets('przywrócenie zastępuje dane po potwierdzeniu', (tester) async {
    // Kopia z innej bazy: dwa treningi.
    final other = memoryDatabase();
    late String backupJson;
    await tester.runAsync(() async {
      for (final e in catalog.values) {
        await DriftExerciseRepository(other, testClock()).save(e);
      }
      await DriftTemplateRepository(other, testClock()).save(pushTemplate());
      final workouts = DriftWorkoutRepository(other, testClock());
      await workouts.save(
        finishedPush('x', DateTime.utc(2026, 9, 1, 16), [(70000, 10)]),
      );
      await workouts.save(
        finishedPush('y', DateTime.utc(2026, 9, 8, 16), [(72500, 10)]),
      );
      backupJson = jsonEncode(
        await BackupStore(other, testClock()).exportAll(appVersion: 'test'),
      );
      await other.close();
    });
    final files = FakeFileExchange()..toPick = backupJson;
    final safety = <String>[];
    final db = await _openBackup(tester, files: files, safetyCopies: safety);

    await _tap(tester, find.text('Przywróć z pliku'));
    expect(find.text('Przywrócić dane z kopii?'), findsOneWidget);
    expect(find.textContaining('2 treningi, 1 szablon'), findsOneWidget);
    await _tap(tester, find.text('Anuluj'));
    expect(await _sessionCount(tester, db), 1);

    await _tap(tester, find.text('Przywróć z pliku'));
    await _tap(tester, find.text('Przywróć'));

    expect(find.text('Przywrócono dane z kopii'), findsOneWidget);
    expect(await _sessionCount(tester, db), 2);
    // Kopia bezpieczeństwa zawiera dane sprzed przywrócenia.
    final before = readBackup(safety.single);
    expect(before['workoutSessions'], hasLength(1));

    await closeRepTrack(tester, db);
  });

  testWidgets('uszkodzony plik nie zmienia danych', (tester) async {
    final files = FakeFileExchange()..toPick = '{"format": "reptrack-backup"';
    final db = await _openBackup(tester, files: files);

    await _tap(tester, find.text('Przywróć z pliku'));

    expect(find.text('Nie można przywrócić'), findsOneWidget);
    await _tap(tester, find.text('OK'));
    expect(await _sessionCount(tester, db), 1);

    await closeRepTrack(tester, db);
  });

  testWidgets('kopia z nowszej wersji jest odrzucana', (tester) async {
    final files = FakeFileExchange()
      ..toPick = jsonEncode({'format': 'reptrack-backup', 'formatVersion': 9});
    final db = await _openBackup(tester, files: files);

    await _tap(tester, find.text('Przywróć z pliku'));

    expect(find.text('Kopia z nowszej wersji'), findsOneWidget);
    expect(find.textContaining('format 9'), findsOneWidget);

    await closeRepTrack(tester, db);
  });

  testWidgets('eksport CSV i Markdown', (tester) async {
    final files = FakeFileExchange();
    // Wysoki ekran: cały formularz eksportu bez przewijania.
    final db = await _openBackup(tester, files: files, height: 1400);

    expect(find.text('Serii: 1 · treningów: 1'), findsOneWidget);
    await _tap(tester, find.text('Udostępnij'));
    final csv = files.sharedFiles.single;
    expect(csv.fileName, endsWith('.csv'));
    expect(csv.content, startsWith('﻿Data;Godzina;Trening'));
    expect(csv.content, contains(';80;10;'));

    await _tap(tester, find.text('Markdown'));
    await _tap(tester, find.text('Udostępnij'));
    expect(files.sharedTexts.single, startsWith('# RepTrack: treningi'));

    // Trening z 12 października mieści się w ostatnich 30 dniach.
    await _tap(tester, find.text('30 dni'));
    expect(find.text('Serii: 1 · treningów: 1'), findsOneWidget);

    await closeRepTrack(tester, db);
  });

  testWidgets('przerwa z kopii dostaje powiadomienie od nowa', (tester) async {
    final restEnds = DateTime.utc(2026, 10, 19, 18, 2);
    final other = memoryDatabase();
    late String backupJson;
    await tester.runAsync(() async {
      for (final e in catalog.values) {
        await DriftExerciseRepository(other, testClock()).save(e);
      }
      await DriftTemplateRepository(other, testClock()).save(pushTemplate());
      await DriftWorkoutRepository(other, testClock()).save(
        finishedPush('r', DateTime.utc(2026, 10, 19, 17, 30), [
          (80000, 10),
        ]).copyWith(
          status: SessionStatus.active,
          endedAt: null,
          restEndsAt: restEnds,
        ),
      );
      backupJson = jsonEncode(
        await BackupStore(other, testClock()).exportAll(appVersion: 'test'),
      );
      await other.close();
    });
    final notifications = FakeRestNotifications();
    final db = await _openBackup(
      tester,
      files: FakeFileExchange()..toPick = backupJson,
      notifications: notifications,
    );

    await _tap(tester, find.text('Przywróć z pliku'));
    await _tap(tester, find.text('Przywróć'));

    expect(find.text('Przywrócono dane z kopii'), findsOneWidget);
    expect(notifications.cancelCount, greaterThanOrEqualTo(1));
    expect(notifications.endsAt, restEnds);

    await closeRepTrack(tester, db);
  });

  testWidgets('kopia bez treningu: powiadomienie przerwy znika', (
    tester,
  ) async {
    final other = memoryDatabase();
    late String backupJson;
    await tester.runAsync(() async {
      backupJson = jsonEncode(
        await BackupStore(other, testClock()).exportAll(appVersion: 'test'),
      );
      await other.close();
    });
    final notifications = FakeRestNotifications();
    final db = await _openBackup(
      tester,
      files: FakeFileExchange()..toPick = backupJson,
      notifications: notifications,
    );
    await notifications.startRest(
      endsAt: DateTime.utc(2026, 10, 19, 18, 3),
      nextName: 'Wyciskanie',
    );

    await _tap(tester, find.text('Przywróć z pliku'));
    await _tap(tester, find.text('Przywróć'));

    expect(notifications.endsAt, isNull);

    await closeRepTrack(tester, db);
  });
}
