import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reptrack/core/database/app_database.dart';
import 'package:reptrack/features/exercises/data/drift_exercise_repository.dart';
import 'package:reptrack/features/templates/data/drift_template_repository.dart';
import 'package:reptrack/features/workout/data/drift_workout_repository.dart';
import 'package:reptrack/features/workout/domain/session_editing.dart';
import 'package:reptrack/features/workout/domain/workout_session.dart';

import '../../../support/app_harness.dart';
import '../../../support/test_database.dart';
import '../../../support/workout_fixtures.dart';

final _oct12 = finishedPush('b', DateTime.utc(2026, 10, 12, 16), [
  (80000, 10),
  (80000, 9),
]);
final _oct19 = finishedPush('c', DateTime.utc(2026, 10, 19, 16), [
  (85000, 8),
  (85000, 7),
]);

/// Aplikacja na telefonie 360 × 800 dp z dwoma zakończonymi treningami.
Future<AppDatabase> _launch(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final db = widgetTestDatabase();
  await tester.runAsync(() async {
    final exercises = DriftExerciseRepository(db, testClock());
    for (final e in catalog.values) {
      await exercises.save(e);
    }
    await DriftTemplateRepository(db, testClock()).save(pushTemplate());
    final workouts = DriftWorkoutRepository(db, testClock());
    await workouts.save(_oct12);
    await workouts.save(_oct19);
  });
  return pumpRepTrack(tester, db: db, clock: testClock());
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<WorkoutSession?> _session(
  WidgetTester tester,
  AppDatabase db,
  String id,
) => tester
    .runAsync(() => DriftWorkoutRepository(db, testClock()).findById(id))
    .then((s) => s);

/// Przewijana lista o kluczu [key] (zakładki mają kilka list naraz).
Finder _scrollableIn(Key key) => find
    .descendant(of: find.byKey(key), matching: find.byType(Scrollable))
    .first;

/// Otwiera najnowszy trening z listy historii.
Future<void> _openLatest(WidgetTester tester) async {
  await _tap(tester, navTab('Historia'));
  await _tap(tester, find.text('Push A').first);
}

void main() {
  testWidgets('lista historii i korekta serii w szczegółach', (tester) async {
    final db = await _launch(tester);
    await _tap(tester, navTab('Historia'));

    expect(find.text('październik 2026'), findsOneWidget);
    expect(find.text('Push A'), findsNWidgets(2));
    await _tap(tester, find.text('Push A').first);

    expect(find.text('Wyciskanie'), findsOneWidget);
    expect(find.text('85×8'), findsOneWidget);
    expect(find.textContaining('pon., 19 paź · 18:00'), findsOneWidget);

    await _tap(tester, find.byTooltip('Edytuj trening'));
    await _tap(tester, find.text('85×8'));
    await tester.enterText(find.widgetWithText(TextField, 'Powtórzenia'), '10');
    await _tap(tester, find.text('Gotowe'));
    expect(find.text('85×10'), findsOneWidget);
    await _tap(tester, find.text('Zapisz'));

    expect(find.text('Zapisano zmiany'), findsOneWidget);
    final saved = (await _session(tester, db, _oct19.id))!;
    final bench = sortedSets(sortedExercises(saved).first);
    expect((bench[1].weightG, bench[1].reps), (85000, 10));
    expect(saved.status, SessionStatus.completed);

    await closeRepTrack(tester, db);
  });

  testWidgets('dodanie serii w edycji i porzucenie zmian', (tester) async {
    final db = await _launch(tester);
    await _openLatest(tester);

    await _tap(tester, find.byTooltip('Edytuj trening'));
    await _tap(tester, find.text('Dodaj serię').first);
    await _tap(tester, find.byTooltip('Zamknij'));
    expect(find.text('Odrzucić zmiany w treningu?'), findsOneWidget);
    await _tap(tester, find.text('Odrzuć'));

    final saved = (await _session(tester, db, _oct19.id))!;
    expect(sortedExercises(saved).first.sets, hasLength(4));

    await closeRepTrack(tester, db);
  });

  testWidgets('porównanie z poprzednim treningiem', (tester) async {
    final db = await _launch(tester);
    await _openLatest(tester);

    await _tap(tester, find.byTooltip('Porównaj z poprzednim'));

    expect(find.text('Porównanie'), findsOneWidget);
    // Ławka i podciąganie mają poprzednie wykonanie z 12 października.
    expect(find.text('Poprzednio · pon., 12 paź'), findsNWidgets(2));
    expect(find.text('85×8 · 85×7'), findsOneWidget);
    expect(find.text('80×10 · 80×9'), findsOneWidget);
    expect(find.text('Objętość'), findsOneWidget);

    await closeRepTrack(tester, db);
  });

  testWidgets('usunięcie treningu z historii', (tester) async {
    final db = await _launch(tester);
    await _openLatest(tester);

    await _tap(tester, find.byTooltip('Więcej akcji'));
    await _tap(tester, find.text('Usuń trening'));
    expect(find.text('Usunąć trening?'), findsOneWidget);
    await _tap(tester, find.text('Usuń'));

    expect(find.text('Trening usunięty'), findsOneWidget);
    expect(find.text('Push A'), findsOneWidget);
    expect(await _session(tester, db, _oct19.id), isNull);

    await closeRepTrack(tester, db);
  });

  testWidgets('Start: ostatni szablon i pierwsza seria w 2 tapnięciach', (
    tester,
  ) async {
    final db = await _launch(tester);

    expect(find.text('1 trening'), findsOneWidget);
    expect(find.text('Ostatni trening'), findsOneWidget);
    await _tap(tester, find.text('Rozpocznij: Push A'));
    await _tap(tester, find.text('Zatwierdź serię 1'));

    final active = (await tester.runAsync(
      () => DriftWorkoutRepository(db, testClock()).findActive(),
    ))!;
    expect(sortedSets(sortedExercises(active).first).first.isCompleted, isTrue);

    await tester.pump(const Duration(milliseconds: 400));
    await closeRepTrack(tester, db);
  });

  testWidgets('ekran ćwiczenia: historia, rekordy i wykresy', (tester) async {
    final db = await _launch(tester);
    await _tap(tester, navTab('Ćwiczenia'));
    await _tap(tester, find.text('Wyciskanie'));

    await _tap(
      tester,
      find.descendant(of: find.byType(TabBar), matching: find.text('Historia')),
    );
    expect(find.text('pon., 19 paź · Push A'), findsOneWidget);
    expect(find.text('85×8 · 85×7'), findsOneWidget);

    await _tap(tester, find.text('Rekordy'));
    expect(find.text('Szacowany 1RM'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('≥ 10 powt.'),
      200,
      scrollable: _scrollableIn(const PageStorageKey('exercise-records')),
    );
    expect(find.text('≥ 10 powt.'), findsOneWidget);

    await _tap(tester, find.text('Wykresy'));
    expect(find.byType(LineChart), findsOneWidget);
    expect(find.byType(BarChart), findsOneWidget);

    await closeRepTrack(tester, db);
  });

  testWidgets('progres: treningi w tygodniu i wykresy ćwiczenia', (
    tester,
  ) async {
    final db = await _launch(tester);
    await _tap(tester, navTab('Historia'));
    await _tap(tester, find.text('Progres'));

    expect(find.text('Treningi w tygodniu'), findsOneWidget);
    expect(find.byType(BarChart), findsWidgets);
    expect(find.text('Wyciskanie'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byType(LineChart),
      200,
      scrollable: _scrollableIn(const PageStorageKey('progress')),
    );
    expect(find.byType(LineChart), findsOneWidget);

    await closeRepTrack(tester, db);
  });
}
