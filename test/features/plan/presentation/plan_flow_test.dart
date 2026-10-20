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
import '../../../support/fake_devices.dart';
import '../../../support/test_database.dart';
import '../../../support/workout_fixtures.dart';

// Zegar testów: poniedziałek 19.10.2026, 20:00 w Warszawie.
const _week = WeeklyPlan(
  id: 'wp',
  startsOn: LocalDate(2026, 10, 5),
  days: [
    WeeklyPlanDay(id: 'd1', weekday: 1, templateId: 'tpl', position: 0),
    WeeklyPlanDay(id: 'd2', weekday: 3, templateId: 'tpl2', position: 0),
  ],
);

/// Plan: pon „Push A”, śr „Pull B” od 5.10; zrobiony tylko pon 12.10.
Future<AppDatabase> _launch(
  WidgetTester tester, {
  bool withPlan = true,
  FakePlanReminders? reminders,
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
    await DriftWorkoutRepository(db, testClock()).save(
      finishedPush('b', DateTime.utc(2026, 10, 12, 16), [
        (80000, 10),
        (80000, 9),
      ]),
    );
    if (withPlan) {
      await DriftPlanRepository(db, testClock()).saveWeekly(save: [_week]);
    }
  });
  final app = await pumpRepTrack(
    tester,
    seed: false,
    db: db,
    clock: testClock(),
    reminders: reminders,
  );
  await _tap(tester, navTab('Plan'));
  return app;
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// Komórka kalendarza po początku etykiety czytnika, np. „Wtorek, 20 …”.
Finder _day(String start) => find.bySemanticsLabel(RegExp('^$start'));

Future<PlanState> _plan(WidgetTester tester, AppDatabase db) async =>
    (await tester.runAsync(() => DriftPlanRepository(db, testClock()).load()))!;

void main() {
  testWidgets('realizacja tygodnia, znaczniki i karta dzisiejszego dnia', (
    tester,
  ) async {
    final db = await _launch(tester);

    expect(find.text('Ten tydzień'), findsOneWidget);
    expect(find.text('0 z 2'), findsOneWidget);
    expect(find.text('2 treningi przed Tobą'), findsOneWidget);
    expect(_day('Poniedziałek, 12 października: Push A: zrobiony'), findsOne);
    expect(_day('Środa, 14 października: Pull B: pominięty'), findsOne);
    expect(_day('Wtorek, 13 października: nic nie zaplanowano'), findsOne);

    // Karta dnia bez wchodzenia w szczegóły.
    expect(find.text('Poniedziałek, 19 października · dziś'), findsOneWidget);
    expect(find.text('Na dziś'), findsOneWidget);
    expect(find.text('2 ćwiczenia · 7 serii · ok. 20 min'), findsOneWidget);
    expect(find.text('Wyciskanie, Podciąganie'), findsOneWidget);
    expect(find.text('Rozpocznij'), findsOneWidget);

    await closeRepTrack(tester, db);
  });

  testWidgets('zrobiony trening w karcie dnia prowadzi do szczegółów', (
    tester,
  ) async {
    final db = await _launch(tester);

    await _tap(tester, _day('Poniedziałek, 12 października'));
    expect(find.text('Zrobiony'), findsOneWidget);
    expect(find.textContaining('18:00 · 50 min · 2 serie'), findsOneWidget);
    await _tap(tester, find.text('Push A').last);
    expect(find.byTooltip('Porównaj z poprzednim'), findsOneWidget);

    await closeRepTrack(tester, db);
  });

  testWidgets('zaplanuj trening na dzień, przesuń na jutro i przywróć', (
    tester,
  ) async {
    final db = await _launch(tester);

    await _tap(tester, _day('Wtorek, 20 października'));
    expect(find.text('Dzień wolny'), findsOneWidget);
    await _tap(tester, find.text('Zaplanuj trening'));
    await _tap(tester, find.text('Push A'));
    expect(find.text('Zaplanowany'), findsOneWidget);
    expect(find.text('Zmieniony względem planu tygodnia'), findsOneWidget);

    await _tap(tester, find.byTooltip('Opcje treningu z planu'));
    await _tap(tester, find.text('Przesuń na jutro'));
    expect(find.text('Dzień wolny'), findsOneWidget);
    var plan = await _plan(tester, db);
    final wednesday = plan.days.where(
      (d) => d.date == const LocalDate(2026, 10, 21),
    );
    expect([for (final d in wednesday) d.templateId], ['tpl2', 'tpl']);

    // Snackbar „Przesunięto…” zasłania dół ekranu: czekamy, aż zniknie.
    await tester.pump(const Duration(seconds: 7));
    await tester.pumpAndSettle();
    await _tap(tester, find.text('Przywróć plan tygodnia'));
    plan = await _plan(tester, db);
    expect(
      plan.days.any((d) => d.date == const LocalDate(2026, 10, 20)),
      isFalse,
    );

    await closeRepTrack(tester, db);
  });

  testWidgets('pominięcie dzisiejszego treningu zmienia realizację', (
    tester,
  ) async {
    final db = await _launch(tester);

    await _tap(tester, find.byTooltip('Opcje treningu z planu'));
    await _tap(tester, find.text('Pomiń'));

    expect(find.text('Pominięto trening'), findsOneWidget);
    expect(find.text('Dzień wolny'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Ten tydzień'), -300);
    expect(find.text('0 z 1'), findsOneWidget);

    // „Cofnij” przywraca dzisiejszy trening.
    await _tap(tester, find.text('Cofnij'));
    expect(find.text('0 z 2'), findsOneWidget);

    await closeRepTrack(tester, db);
  });

  testWidgets('„Rozpocznij” z planu otwiera trening z szablonu', (
    tester,
  ) async {
    final db = await _launch(tester);

    await _tap(tester, find.text('Rozpocznij'));

    expect(find.text('Zatwierdź serię 1'), findsOneWidget);
    final active = await tester.runAsync(
      () => DriftWorkoutRepository(db, testClock()).findActive(),
    );
    expect(active!.templateId, 'tpl');

    await closeRepTrack(tester, db);
  });

  testWidgets('widok tygodnia: opis każdego dnia', (tester) async {
    final db = await _launch(tester);

    await _tap(tester, find.text('Tydzień'));

    expect(find.text('19–25 paź'), findsOneWidget);
    expect(find.text('Poniedziałek, 19 października · dziś'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Środa, 21 października'),
      300,
      scrollable: find
          .descendant(
            of: find.byKey(const PageStorageKey('plan')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.text('Pull B'), findsOneWidget);

    await closeRepTrack(tester, db);
  });

  testWidgets(
    'edytor planu tygodnia: nowa wersja od dziś, przeszłość bez zmian',
    (tester) async {
      final db = await _launch(tester);

      await _tap(tester, find.byTooltip('Edytuj plan tygodnia'));
      expect(find.text('Plan tygodnia'), findsOneWidget);
      await _tap(tester, find.byTooltip('Usuń Push A z dnia'));
      await _tap(tester, find.text('Dodaj trening').at(4));
      await _tap(tester, find.text('Push A'));
      await _tap(tester, find.text('Zapisz'));

      expect(find.text('Zapisano plan tygodnia'), findsOneWidget);
      final plan = await _plan(tester, db);
      expect(plan.weekly, hasLength(2));
      expect(plan.weekly.first.endsOn, const LocalDate(2026, 10, 18));
      expect(plan.weekly.last.startsOn, const LocalDate(2026, 10, 19));
      // Dawny poniedziałek dalej pokazuje zrobiony Push A.
      expect(_day('Poniedziałek, 12 października: Push A: zrobiony'), findsOne);
      expect(find.text('Dzień wolny'), findsOneWidget);

      await closeRepTrack(tester, db);
    },
  );

  testWidgets('wyjście z edytora ze zmianami pyta o odrzucenie', (
    tester,
  ) async {
    final db = await _launch(tester);

    await _tap(tester, find.byTooltip('Edytuj plan tygodnia'));
    await _tap(tester, find.byTooltip('Usuń Push A z dnia'));
    await _tap(tester, find.byTooltip('Wstecz'));
    expect(find.text('Odrzucić zmiany?'), findsOneWidget);
    await _tap(tester, find.text('Odrzuć'));

    expect(find.text('Ten tydzień'), findsOneWidget);
    expect((await _plan(tester, db)).weekly, hasLength(1));

    await closeRepTrack(tester, db);
  });

  testWidgets('bez planu: zachęta do ułożenia tygodnia', (tester) async {
    final db = await _launch(tester, withPlan: false);

    expect(find.text('Zaplanuj swój tydzień'), findsOneWidget);
    await _tap(
      tester,
      find.widgetWithText(FilledButton, 'Edytuj plan tygodnia'),
    );
    expect(find.text('Plan tygodnia'), findsOneWidget);

    await closeRepTrack(tester, db);
  });

  testWidgets('przypomnienia: zgoda, zapis i zaplanowane dni', (tester) async {
    final reminders = FakePlanReminders();
    final db = await _launch(tester, reminders: reminders);
    expect(reminders.scheduled, isEmpty);

    await _tap(tester, find.byTooltip('Edytuj plan tygodnia'));
    await tester.scrollUntilVisible(find.text('Przypomnienie o treningu'), 300);
    expect(find.text('Wyłączone'), findsOneWidget);
    await _tap(tester, find.text('Przypomnienie o treningu'));

    expect(reminders.permissionRequests, 1);
    expect(find.text('W dni z planem o 17:00'), findsOneWidget);
    // Dziś 20:00 po 17:00: pierwsze przypomnienie w środę o „Pull B”.
    expect(reminders.scheduled.first.workouts, ['Pull B']);
    expect(reminders.scheduled.first.at.toLocal(), DateTime(2026, 10, 21, 17));

    await closeRepTrack(tester, db);
  });

  testWidgets('przypomnienia bez zgody na powiadomienia zostają wyłączone', (
    tester,
  ) async {
    final reminders = FakePlanReminders()..allowed = false;
    final db = await _launch(tester, reminders: reminders);

    await _tap(tester, find.byTooltip('Edytuj plan tygodnia'));
    await tester.scrollUntilVisible(find.text('Przypomnienie o treningu'), 300);
    await _tap(tester, find.text('Przypomnienie o treningu'));

    expect(find.textContaining('Bez zgody na powiadomienia'), findsOneWidget);
    expect(find.text('Wyłączone'), findsOneWidget);
    expect(reminders.scheduled, isEmpty);

    await closeRepTrack(tester, db);
  });
}
