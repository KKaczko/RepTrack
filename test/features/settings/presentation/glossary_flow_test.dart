import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reptrack/core/database/app_database.dart';
import 'package:reptrack/features/exercises/data/drift_exercise_repository.dart';
import 'package:reptrack/features/templates/data/drift_template_repository.dart';
import 'package:reptrack/features/workout/data/drift_workout_repository.dart';

import '../../../support/app_harness.dart';
import '../../../support/test_database.dart';
import '../../../support/workout_fixtures.dart';

/// Aplikacja z jednym zakończonym treningiem (zakładka Progres ma dane).
Future<AppDatabase> _launch(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final db = widgetTestDatabase();
  await tester.runAsync(() async {
    for (final e in catalog.values) {
      await DriftExerciseRepository(db, testClock()).save(e);
    }
    await DriftTemplateRepository(db, testClock()).save(pushTemplate());
    await DriftWorkoutRepository(db, testClock()).save(
      finishedPush('a', DateTime.utc(2026, 10, 12, 16), [
        (80000, 10),
        (80000, 9),
      ]),
    );
  });
  return pumpRepTrack(tester, db: db, clock: testClock());
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('słowniczek z ustawień: grupy i pojęcia', (tester) async {
    final db = await _launch(tester);

    await _tap(tester, find.byTooltip('Otwórz ustawienia'));
    await tester.scrollUntilVisible(find.text('Słowniczek pojęć'), 300);
    await _tap(tester, find.text('Słowniczek pojęć'));

    expect(find.text('Słowniczek'), findsOneWidget);
    expect(find.text('Podstawy'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Szacowany 1RM'), 300);
    expect(find.textContaining('wzoru Epleya'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Progresja'), 300);

    await closeRepTrack(tester, db);
  });

  testWidgets('ⓘ w ustawieniach opisuje RIR i RPE', (tester) async {
    final db = await _launch(tester);

    await _tap(tester, find.byTooltip('Otwórz ustawienia'));
    await _tap(
      tester,
      find.byTooltip('Co to jest: RIR (powtórzenia w zapasie)?'),
    );

    expect(find.text('RIR (powtórzenia w zapasie)'), findsOneWidget);
    expect(find.text('RPE (odczuwany wysiłek)'), findsOneWidget);
    expect(find.textContaining('RPE = 10 − RIR'), findsOneWidget);

    await closeRepTrack(tester, db);
  });

  testWidgets('ⓘ w progresie: arkusz nad nawigacją i przejście do '
      'słowniczka', (tester) async {
    final db = await _launch(tester);

    await _tap(tester, navTab('Historia'));
    await _tap(tester, find.text('Progres'));
    final info = find.byTooltip('Co to jest: Serie na partię mięśniową?');
    await tester.scrollUntilVisible(
      info,
      200,
      scrollable: find
          .descendant(
            of: find.byKey(const PageStorageKey('progress')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await _tap(tester, info);

    expect(find.textContaining('0,5 dla pomocniczych'), findsWidgets);
    expect(find.byType(NavigationBar).hitTestable(), findsNothing);

    await _tap(tester, find.text('Wszystkie pojęcia'));
    expect(find.text('Słowniczek'), findsOneWidget);
    expect(find.text('Wszystkie pojęcia'), findsNothing);

    await _tap(tester, find.byTooltip('Wstecz'));
    expect(find.text('Progres'), findsOneWidget);

    await closeRepTrack(tester, db);
  });

  testWidgets('ⓘ na ekranie ćwiczenia: mięśnie i tryb obciążenia', (
    tester,
  ) async {
    final db = await _launch(tester);

    await _tap(tester, navTab('Ćwiczenia'));
    await _tap(tester, find.text('Wyciskanie'));
    await _tap(
      tester,
      find.byTooltip('Co to jest: Mięśnie główne i pomocnicze?'),
    );
    expect(find.textContaining('w wyciskaniu leżąc'), findsOneWidget);
    await tester.tapAt(const Offset(180, 40));
    await tester.pumpAndSettle();

    await _tap(tester, find.byTooltip('Co to jest: Tryb obciążenia?'));
    expect(find.textContaining('Skąd bierze się ciężar'), findsOneWidget);

    await closeRepTrack(tester, db);
  });
}
