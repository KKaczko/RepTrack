import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reptrack/core/database/app_database.dart';
import 'package:reptrack/core/domain/training.dart';
import 'package:reptrack/features/exercises/data/exercise_seeder.dart';
import 'package:reptrack/features/exercises/data/seed_catalog.dart';
import 'package:reptrack/features/templates/data/drift_template_repository.dart';
import 'package:reptrack/features/templates/domain/template.dart';
import 'package:reptrack/features/workout/data/drift_workout_repository.dart';
import 'package:reptrack/features/workout/domain/session_editing.dart';

import '../../../support/app_harness.dart';
import '../../../support/test_database.dart';

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// Szablon „Nogi” z przysiadem 3 × 5 przy 100 kg.
Future<AppDatabase> _launch(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final db = widgetTestDatabase();
  await tester.runAsync(() async {
    final catalog = parseSeedCatalog(await File(seedAssetPath).readAsString());
    await ExerciseSeeder(db, testClock()).apply(catalog);
    final squat = seedIdsByKey(
      await File(seedAssetPath).readAsString(),
    )['back_squat']!;
    await DriftTemplateRepository(db, testClock()).save(
      Template(
        id: 'tpl',
        name: 'Nogi',
        exercises: [
          TemplateExercise(
            id: 'te',
            exerciseId: squat,
            position: 0,
            targetMin: 5,
            targetMax: 5,
            targetWeightG: 100000,
            sets: [
              for (var i = 0; i < 3; i++) TemplateSet(id: 's$i', position: i),
            ],
          ),
        ],
      ),
    );
  });
  return pumpRepTrack(tester, seed: false, db: db, clock: testClock());
}

Future<List<(SetType, int?, int?)>> _sets(
  WidgetTester tester,
  AppDatabase db,
) async {
  final session = await tester.runAsync(
    () => DriftWorkoutRepository(db, testClock()).findActive(),
  );
  return [
    for (final s in sortedSets(sortedExercises(session!).single))
      (s.setType, s.targetWeightG, s.targetMin),
  ];
}

void main() {
  testWidgets('rozgrzewka jednym tapnięciem i „Cofnij”', (tester) async {
    final db = await _launch(tester);
    await _tap(tester, find.text('Rozpocznij: Nogi'));
    // Przycisk rozgrzewki i linia talerzy spełniają wytyczne dostępności.
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));

    await _tap(tester, find.text('Rozgrzewka'));

    expect(find.text('Dodano 3 serie rozgrzewkowe'), findsOneWidget);
    // Komunikat nad strefą kciuka: nie zasłania „Zatwierdź serię”.
    expect(
      tester.getBottomLeft(find.text('Dodano 3 serie rozgrzewkowe')).dy,
      lessThanOrEqualTo(tester.getTopLeft(find.text('Ciężar (kg)')).dy),
    );
    expect((await _sets(tester, db)).take(3), [
      (SetType.warmup, 40000, 8),
      (SetType.warmup, 60000, 5),
      (SetType.warmup, 80000, 3),
    ]);
    expect(find.text('Rozgrzewka'), findsNothing);
    expect(find.text('Zatwierdź serię 1'), findsOneWidget);

    await _tap(tester, find.text('Cofnij'));
    expect(await _sets(tester, db), hasLength(3));
    expect(find.text('Rozgrzewka'), findsOneWidget);

    await closeRepTrack(tester, db);
  });
}
