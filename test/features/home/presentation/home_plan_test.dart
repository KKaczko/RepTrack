import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reptrack/core/database/app_database.dart';
import 'package:reptrack/core/domain/local_date.dart';
import 'package:reptrack/features/exercises/data/drift_exercise_repository.dart';
import 'package:reptrack/features/plan/data/drift_plan_repository.dart';
import 'package:reptrack/features/plan/domain/plan.dart';
import 'package:reptrack/features/templates/data/drift_template_repository.dart';
import 'package:reptrack/features/workout/data/drift_workout_repository.dart';

import '../../../support/app_harness.dart';
import '../../../support/test_database.dart';
import '../../../support/workout_fixtures.dart';

// Zegar testów: poniedziałek 19.10.2026, 20:00 w Warszawie.

/// Start z planem [days] (dzień tygodnia → szablon) od 5.10 i opcjonalnie
/// treningiem „Push A” zrobionym dziś.
Future<AppDatabase> _launch(
  WidgetTester tester, {
  required Map<int, String> days,
  bool doneToday = false,
}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final db = widgetTestDatabase();
  await tester.runAsync(() async {
    for (final e in catalog.values) {
      await DriftExerciseRepository(db, testClock()).save(e);
    }
    final templates = DriftTemplateRepository(db, testClock());
    await templates.save(pushTemplate());
    await templates.save(
      pushTemplate().copyWith(id: 'tpl2', name: 'Pull B', exercises: []),
    );
    if (doneToday) {
      await DriftWorkoutRepository(
        db,
        testClock(),
      ).save(finishedPush('t', DateTime.utc(2026, 10, 19, 15), [(80000, 8)]));
    }
    await DriftPlanRepository(db, testClock()).saveWeekly(
      save: [
        WeeklyPlan(
          id: 'wp',
          startsOn: const LocalDate(2026, 10, 5),
          days: [
            for (final MapEntry(key: weekday, value: template) in days.entries)
              WeeklyPlanDay(
                id: 'd$weekday',
                weekday: weekday,
                templateId: template,
                position: 0,
              ),
          ],
        ),
      ],
    );
  });
  return pumpRepTrack(tester, seed: false, db: db, clock: testClock());
}

void main() {
  testWidgets('dzisiejszy trening z planu jest głównym przyciskiem', (
    tester,
  ) async {
    final db = await _launch(tester, days: {1: 'tpl', 3: 'tpl2'});

    expect(find.text('Dziś wg planu: Push A'), findsOneWidget);
    expect(find.text('0 z 2 treningów z planu'), findsOneWidget);

    await tester.tap(find.text('Dziś wg planu: Push A'));
    await tester.pumpAndSettle();
    expect(find.text('Zatwierdź serię 1'), findsOneWidget);

    await closeRepTrack(tester, db);
  });

  testWidgets('plan na dziś zrobiony: stan i następny trening', (tester) async {
    final db = await _launch(
      tester,
      days: {1: 'tpl', 3: 'tpl2'},
      doneToday: true,
    );

    expect(find.text('Plan na dziś wykonany'), findsOneWidget);
    expect(find.text('Następny: środa · Pull B'), findsOneWidget);
    expect(find.text('Rozpocznij: Push A'), findsOneWidget);
    expect(find.text('1 z 2 treningów z planu'), findsOneWidget);

    await tester.tap(find.text('Zobacz plan'));
    await tester.pumpAndSettle();
    expect(find.text('Ten tydzień'), findsOneWidget);

    await closeRepTrack(tester, db);
  });

  testWidgets('dzień wolny w planie: następny jutro', (tester) async {
    final db = await _launch(tester, days: {2: 'tpl2'});

    expect(find.text('Dziś dzień wolny'), findsOneWidget);
    expect(find.text('Następny: jutro · Pull B'), findsOneWidget);

    await closeRepTrack(tester, db);
  });
}
