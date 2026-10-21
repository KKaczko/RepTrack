import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reptrack/core/database/app_database.dart';
import 'package:reptrack/features/exercises/data/drift_substitute_repository.dart';
import 'package:reptrack/features/exercises/data/exercise_seeder.dart';
import 'package:reptrack/features/exercises/data/seed_catalog.dart';
import 'package:reptrack/features/templates/data/drift_template_repository.dart';
import 'package:reptrack/features/templates/domain/template.dart';
import 'package:reptrack/features/workout/data/drift_workout_repository.dart';

import '../../../support/app_harness.dart';
import '../../../support/fakes.dart';
import '../../../support/test_database.dart';

const _machine = 'Wyciskanie na maszynie siedząc';
const _dumbbell = 'Wyciskanie hantli na ławce płaskiej';

/// Prawdziwa biblioteka ćwiczeń i szablon „Klatka” z wyciskaniem na maszynie
/// (3 × 8–12, 50 kg), żeby propozycje były takie, jak zobaczy użytkownik.
Future<AppDatabase> _launch(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final db = widgetTestDatabase();
  await tester.runAsync(() async {
    final catalog = parseSeedCatalog(await File(seedAssetPath).readAsString());
    await ExerciseSeeder(db, testClock()).apply(catalog);
    final machine = catalog.exercises.firstWhere((e) => e.name == _machine);
    await DriftTemplateRepository(db, testClock()).save(
      Template(
        id: 'tpl',
        name: 'Klatka',
        exercises: [
          TemplateExercise(
            id: 'te',
            exerciseId: machine.id,
            position: 0,
            targetMin: 8,
            targetMax: 12,
            targetWeightG: 50000,
            sets: [
              for (var i = 0; i < 3; i++) TemplateSet(id: 's$i', position: i),
            ],
          ),
        ],
      ),
    );
  });
  final app = await pumpRepTrack(
    tester,
    seed: false,
    db: db,
    clock: testClock(),
  );
  await _tap(tester, find.text('Rozpocznij: Klatka'));
  return app;
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// Nazwa ćwiczenia w nagłówku strony treningu.
Future<String?> _activeExercise(WidgetTester tester, AppDatabase db) async {
  final session = await tester.runAsync(
    () => DriftWorkoutRepository(db, testClock()).findActive(),
  );
  return session?.exercises.single.exerciseNameSnapshot;
}

void main() {
  testWidgets('zajęta maszyna: przypięcie i zamiana na zamiennik', (
    tester,
  ) async {
    final db = await _launch(tester);

    await _tap(tester, find.text('Zamiennik'));
    expect(find.text('Zamienniki: $_machine'), findsOneWidget);
    expect(find.text(_dumbbell), findsOneWidget);

    await _tap(tester, find.byTooltip('Przypnij zamiennik: $_dumbbell'));
    expect(find.byTooltip('Odepnij zamiennik: $_dumbbell'), findsOneWidget);
    expect(find.textContaining('przypięty'), findsOneWidget);
    final pins = await tester.runAsync(
      () => DriftSubstituteRepository(
        db,
        testClock(),
        SequentialIds('p'),
      ).watch().first,
    );
    expect(pins, hasLength(1));

    await _tap(tester, find.text(_dumbbell));
    expect(find.text('Zamienniki: $_machine'), findsNothing);
    expect(await _activeExercise(tester, db), _dumbbell);

    await closeRepTrack(tester, db);
  });

  testWidgets('zamiana po zatwierdzonej serii wymaga potwierdzenia', (
    tester,
  ) async {
    final db = await _launch(tester);

    await _tap(tester, find.text('Zatwierdź serię 1'));
    await tester.pump(const Duration(milliseconds: 400));
    await _tap(tester, find.text('Zamiennik'));
    await _tap(tester, find.text(_dumbbell));

    expect(find.text('Zamienić ćwiczenie?'), findsOneWidget);
    await _tap(tester, find.text('Anuluj'));
    expect(await _activeExercise(tester, db), _machine);

    await closeRepTrack(tester, db);
  });

  testWidgets('„Wybierz z całej biblioteki” otwiera pełną listę', (
    tester,
  ) async {
    final db = await _launch(tester);

    await _tap(tester, find.text('Zamiennik'));
    await _tap(tester, find.text('Wybierz z całej biblioteki'));

    expect(find.text('Szukaj ćwiczenia'), findsOneWidget);

    await closeRepTrack(tester, db);
  });
}
