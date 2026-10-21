import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reptrack/core/database/app_database.dart';
import 'package:reptrack/features/exercises/data/exercise_seeder.dart';
import 'package:reptrack/features/exercises/data/seed_catalog.dart';
import 'package:reptrack/features/templates/data/drift_template_repository.dart';
import 'package:reptrack/features/templates/domain/template.dart';

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

void main() {
  testWidgets('talerze przy sztandze i zmiana gryfu', (tester) async {
    final db = await _launch(tester);
    await _tap(tester, find.text('Rozpocznij: Nogi'));

    expect(find.text('Na stronę: 25 + 15 · gryf 20 kg'), findsOneWidget);
    await _tap(tester, find.text('Na stronę: 25 + 15 · gryf 20 kg'));
    expect(find.text('Gryf i talerze'), findsOneWidget);
    await _tap(tester, find.widgetWithText(ChoiceChip, '15 kg').first);
    await _tap(tester, find.byTooltip('Wstecz'));

    expect(find.text('Na stronę: 25 + 15 + 2,5 · gryf 15 kg'), findsOneWidget);

    await closeRepTrack(tester, db);
  });

  testWidgets('bez talerza 15 kg: inny podział i reszta', (tester) async {
    final db = await _launch(tester);
    await _tap(tester, find.byTooltip('Otwórz ustawienia'));
    await tester.scrollUntilVisible(find.text('Gryf i talerze'), 200);
    await _tap(tester, find.text('Gryf i talerze'));
    await _tap(tester, find.widgetWithText(FilterChip, '15 kg'));
    await _tap(tester, find.widgetWithText(FilterChip, '1,25 kg'));
    await _tap(tester, find.byTooltip('Wstecz'));
    await _tap(tester, find.byTooltip('Wstecz'));
    await _tap(tester, find.text('Rozpocznij: Nogi'));

    expect(find.text('Na stronę: 25 + 10 + 5 · gryf 20 kg'), findsOneWidget);
    await _tap(tester, find.byTooltip('Zwiększ: Ciężar'));
    // 102,5 kg: 41,25 na stronę, bez 1,25 zostaje 1,25 × 2 = 2,5 kg.
    expect(
      find.text(
        'Na stronę: 25 + 10 + 5 · gryf 20 kg · 2,5 kg nie da się złożyć',
      ),
      findsOneWidget,
    );

    await closeRepTrack(tester, db);
  });
}
