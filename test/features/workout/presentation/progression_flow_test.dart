import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reptrack/core/database/app_database.dart';
import 'package:reptrack/features/exercises/data/drift_exercise_repository.dart';
import 'package:reptrack/features/settings/data/drift_settings_repository.dart';
import 'package:reptrack/features/settings/domain/app_settings.dart';
import 'package:reptrack/features/templates/data/drift_template_repository.dart';
import 'package:reptrack/features/workout/data/drift_workout_repository.dart';
import 'package:reptrack/features/workout/domain/session_editing.dart';
import 'package:reptrack/features/workout/domain/workout_session.dart';

import '../../../support/app_harness.dart';
import '../../../support/test_database.dart';
import '../../../support/workout_fixtures.dart';

const _label = '+2,5 kg · ostatnio 3 × 12 przy 80 kg';

/// „Push A” (ławka 3 × 8–12) po treningu z 3 × 12 przy 80 kg.
Future<AppDatabase> _launch(
  WidgetTester tester, {
  bool autoProgression = true,
  List<WorkoutSession>? history,
}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final db = widgetTestDatabase();
  await tester.runAsync(() async {
    for (final e in catalog.values) {
      await DriftExerciseRepository(db, testClock()).save(e);
    }
    await DriftTemplateRepository(db, testClock()).save(pushTemplate());
    for (final session
        in history ??
            [
              finishedPush('a', DateTime.utc(2026, 10, 12, 16), [
                (80000, 12),
                (80000, 12),
                (80000, 12),
              ]),
            ]) {
      await DriftWorkoutRepository(db, testClock()).save(session);
    }
    if (!autoProgression) {
      await DriftSettingsRepository(
        db,
        testClock(),
      ).save(const AppSettings(autoProgression: false));
    }
  });
  final app = await pumpRepTrack(tester, db: db, clock: testClock());
  await _tap(tester, navTab('Szablony'));
  await _tap(tester, find.byTooltip('Rozpocznij trening'));
  return app;
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<List<SessionSet>> _benchSets(WidgetTester tester, AppDatabase db) async {
  final session = await tester.runAsync(
    () => DriftWorkoutRepository(db, testClock()).findActive(),
  );
  return sortedSets(sortedExercises(session!).first);
}

void main() {
  testWidgets('góra zakresu: podpowiedź +2,5 kg i 8 powtórzeń, 1 tapnięcie', (
    tester,
  ) async {
    final db = await _launch(tester);

    expect(find.text(_label), findsOneWidget);
    expect(find.byTooltip('Co to jest: Progresja podwójna?'), findsOneWidget);

    await _tap(tester, find.text('Zatwierdź serię 1'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(
      find.bySemanticsLabel('Ciężar: 82,5 kg, podpowiedź z progresji'),
      findsOneWidget,
    );
    await _tap(tester, find.text('Zatwierdź serię 2'));

    final sets = await _benchSets(tester, db);
    // Rozgrzewka jak ostatnio, pierwsza robocza z progresji.
    expect((sets[0].weightG, sets[0].reps), (40000, 10));
    expect((sets[1].weightG, sets[1].reps), (82500, 8));

    await tester.pump(const Duration(milliseconds: 400));
    await closeRepTrack(tester, db);
  });

  testWidgets('wyłączona progresja: podpowiedź jak ostatnio', (tester) async {
    final db = await _launch(tester, autoProgression: false);

    expect(find.text(_label), findsNothing);
    await _tap(tester, find.text('Zatwierdź serię 1'));
    await tester.pump(const Duration(milliseconds: 400));
    await _tap(tester, find.text('Zatwierdź serię 2'));

    final sets = await _benchSets(tester, db);
    expect((sets[1].weightG, sets[1].reps), (80000, 12));

    await tester.pump(const Duration(milliseconds: 400));
    await closeRepTrack(tester, db);
  });

  testWidgets('deload: dwa słabe treningi, podpowiedź −10%', (tester) async {
    final db = await _launch(
      tester,
      history: [
        finishedPush('a', DateTime.utc(2026, 10, 5, 16), [
          (80000, 7),
          (80000, 6),
          (80000, 6),
        ]),
        finishedPush('b', DateTime.utc(2026, 10, 12, 16), [
          (80000, 7),
          (80000, 7),
          (80000, 6),
        ]),
      ],
    );

    expect(find.text('−10 kg · 2 treningi poniżej zakresu'), findsOneWidget);
    await _tap(tester, find.text('Zatwierdź serię 1'));
    await tester.pump(const Duration(milliseconds: 400));
    await _tap(tester, find.text('Zatwierdź serię 2'));

    final sets = await _benchSets(tester, db);
    expect((sets[1].weightG, sets[1].reps), (70000, 8));

    await tester.pump(const Duration(milliseconds: 400));
    await closeRepTrack(tester, db);
  });
}
