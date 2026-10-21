import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reptrack/features/exercises/domain/exercise.dart';
import 'package:reptrack/features/settings/data/drift_settings_repository.dart';
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

void main() {
  testWidgets('hantle co 2 kg: ustawienie i stepper w treningu', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final db = await pumpRepTrack(tester, clock: testClock());

    await _tap(tester, find.byTooltip('Otwórz ustawienia'));
    await tester.scrollUntilVisible(find.text('Kroki dla sprzętu'), 200);
    expect(find.text('Wszędzie krok ogólny'), findsOneWidget);
    await _tap(tester, find.text('Kroki dla sprzętu'));
    await _tap(tester, find.text('Hantle'));
    await _tap(
      tester,
      find.descendant(
        of: find.byType(SimpleDialog),
        matching: find.text('2 kg'),
      ),
    );
    expect(find.text('2 kg'), findsOneWidget);
    final saved = await tester.runAsync(
      () => DriftSettingsRepository(db, testClock()).load(),
    );
    expect(saved!.equipmentWeightSteps, {Equipment.dumbbell: 2.0});

    await tester.tapAt(const Offset(180, 20));
    await tester.pumpAndSettle();
    expect(find.text('Hantle 2 kg'), findsOneWidget);
    await _tap(tester, find.byTooltip('Wstecz'));
    await _tap(tester, find.text('Pusty trening'));
    await _tap(tester, find.text('Dodaj ćwiczenia'));
    await tester.enterText(
      find.byType(TextField),
      'wyciskanie hantli plaskiej',
    );
    await tester.pumpAndSettle();
    await _tap(tester, find.text('Wyciskanie hantli na ławce płaskiej'));
    await _tap(tester, find.text('Dodaj (1)'));
    await _tap(tester, find.byTooltip('Zwiększ: Ciężar'));
    await _tap(tester, find.byTooltip('Zwiększ: Ciężar'));

    final session = await tester.runAsync(
      () => DriftWorkoutRepository(db, testClock()).findActive(),
    );
    expect(sortedSets(sortedExercises(session!).single).first.weightG, 4000);

    await closeRepTrack(tester, db);
  });
}
