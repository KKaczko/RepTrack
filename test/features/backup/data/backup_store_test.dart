import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:reptrack/core/database/app_database.dart';
import 'package:reptrack/core/domain/ids.dart';
import 'package:reptrack/core/domain/local_date.dart';
import 'package:reptrack/features/backup/data/backup_store.dart';
import 'package:reptrack/features/backup/domain/backup_validation.dart';
import 'package:reptrack/features/exercises/data/drift_exercise_repository.dart';
import 'package:reptrack/features/exercises/data/drift_substitute_repository.dart';
import 'package:reptrack/features/plan/data/drift_plan_repository.dart';
import 'package:reptrack/features/plan/domain/plan.dart';
import 'package:reptrack/features/settings/data/drift_settings_repository.dart';
import 'package:reptrack/features/settings/domain/app_settings.dart';
import 'package:reptrack/features/templates/data/drift_template_repository.dart';
import 'package:reptrack/features/workout/data/drift_workout_repository.dart';
import 'package:reptrack/features/workout/domain/session_builder.dart';

import '../../../support/fakes.dart';
import '../../../support/test_database.dart';
import '../../../support/workout_fixtures.dart';

/// Baza z ćwiczeniami, szablonem, zakończonymi, usuniętym i trwającym
/// treningiem oraz zmienionymi ustawieniami.
Future<void> _fill(AppDatabase db) async {
  final clock = testClock();
  final exercises = DriftExerciseRepository(db, clock);
  for (final e in catalog.values) {
    await exercises.save(e);
  }
  await exercises.setArchived('plank', archived: true);
  await DriftTemplateRepository(db, clock).save(pushTemplate());
  final workouts = DriftWorkoutRepository(db, clock);
  await workouts.save(
    finishedPush('a', DateTime.utc(2026, 10, 5, 16), [(75000, 10)]),
  );
  final deleted = finishedPush('b', DateTime.utc(2026, 10, 12, 16), [
    (80000, 8),
  ]);
  await workouts.save(deleted);
  await workouts.delete(deleted.id);
  await workouts.save(
    buildSessionFromTemplate(
      template: pushTemplate(),
      exercises: catalog,
      ids: SequentialIds('act'),
      startedAt: DateTime.utc(2026, 10, 19, 16),
      timeZone: 'Europe/Warsaw',
    ).copyWith(restEndsAt: DateTime.utc(2026, 10, 19, 16, 3)),
  );
  await DriftSettingsRepository(
    db,
    clock,
  ).save(const AppSettings(weightStep: 1.25, defaultRestSeconds: 90));
  // Plan: zamknięta i bieżąca wersja planu tygodniowego oraz dzień wolny.
  final plan = DriftPlanRepository(db, clock);
  await plan.saveWeekly(
    save: const [
      WeeklyPlan(
        id: 'wp1',
        startsOn: LocalDate(2026, 9, 28),
        endsOn: LocalDate(2026, 10, 11),
        days: [
          WeeklyPlanDay(id: 'wd1', weekday: 1, templateId: 'tpl', position: 0),
        ],
      ),
      WeeklyPlan(
        id: 'wp2',
        startsOn: LocalDate(2026, 10, 12),
        days: [
          WeeklyPlanDay(id: 'wd2', weekday: 3, templateId: 'tpl', position: 0),
        ],
      ),
    ],
  );
  await DriftSubstituteRepository(
    db,
    clock,
    const UuidV7Generator(),
  ).pin('bench', 'pushup');
  await plan.setDay(const LocalDate(2026, 10, 21), const [
    PlannedDay(
      id: 'pd1',
      date: LocalDate(2026, 10, 21),
      kind: PlannedKind.rest,
      position: 0,
    ),
  ]);
}

Map<String, Object?> _withoutExportTime(Map<String, Object?> backup) =>
    Map.of(backup)..remove('exportedAt');

void main() {
  test('eksport i import dają identyczne dane', () async {
    final source = memoryDatabase();
    addTearDown(source.close);
    await _fill(source);
    final exported = await BackupStore(
      source,
      testClock(),
    ).exportAll(appVersion: '1.0.0+1');

    final target = memoryDatabase();
    addTearDown(target.close);
    final validated = readBackup(jsonEncode(exported));
    await BackupStore(target, testClock()).replaceAll(validated);
    final reExported = await BackupStore(
      target,
      testClock(),
    ).exportAll(appVersion: '1.0.0+1');

    expect(_withoutExportTime(reExported), _withoutExportTime(exported));
    // Usunięte i zarchiwizowane wiersze też są w kopii.
    final sessions = exported['workoutSessions']! as List;
    expect(sessions, hasLength(3));
    expect(
      sessions.where((s) => (s as Map)['deletedAt'] != null),
      hasLength(1),
    );
    final restored = await DriftSettingsRepository(target, testClock()).load();
    expect((restored.weightStep, restored.defaultRestSeconds), (1.25, 90));
    // Plan treningów (format v2) przechodzi w całości.
    expect(exported['weeklyPlans'], hasLength(2));
    expect(exported['weeklyPlanDays'], hasLength(2));
    expect(exported['plannedDays'], hasLength(1));
    final plan = await DriftPlanRepository(target, testClock()).load();
    expect(plan.weekly.last.days.single.weekday, 3);
    expect(plan.days.single.kind, PlannedKind.rest);
    // Przypięte zamienniki (format v3).
    expect(exported['exerciseSubstitutes'], hasLength(1));
    final active = await DriftWorkoutRepository(
      target,
      testClock(),
    ).findActive();
    expect(active!.restEndsAt, DateTime.utc(2026, 10, 19, 16, 3));
  });

  test('zastąpienie usuwa poprzednie dane', () async {
    final source = memoryDatabase();
    addTearDown(source.close);
    await _fill(source);
    final empty = memoryDatabase();
    addTearDown(empty.close);
    final emptyBackup = await BackupStore(
      empty,
      testClock(),
    ).exportAll(appVersion: '1.0.0+1');

    await BackupStore(
      source,
      testClock(),
    ).replaceAll(readBackup(jsonEncode(emptyBackup)));

    expect(await source.select(source.exercises).get(), isEmpty);
    expect(await source.select(source.workoutSessions).get(), isEmpty);
    expect(await source.select(source.settings).get(), isEmpty);
  });

  test('błąd w trakcie zapisu wycofuje całą transakcję', () async {
    final db = memoryDatabase();
    addTearDown(db.close);
    await _fill(db);
    final before = await BackupStore(
      db,
      testClock(),
    ).exportAll(appVersion: '1.0.0+1');
    // Błąd w ostatniej serii pojawia się dopiero po usunięciu danych
    // i wstawieniu wcześniejszych wierszy.
    final broken = Map.of(before);
    final sets = [
      for (final s in before['sessionSets']! as List)
        Map<String, Object?>.of(s as Map<String, Object?>),
    ];
    sets.last['position'] = 'zła wartość';
    broken['sessionSets'] = sets;

    await expectLater(
      BackupStore(db, testClock()).replaceAll(broken),
      throwsA(anything),
    );

    final after = await BackupStore(
      db,
      testClock(),
    ).exportAll(appVersion: '1.0.0+1');
    expect(_withoutExportTime(after), _withoutExportTime(before));
  });
}
