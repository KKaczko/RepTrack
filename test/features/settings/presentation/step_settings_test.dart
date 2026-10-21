import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reptrack/core/database/app_database.dart';
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

/// Wybór wartości w oknie ustawienia otwieranym wierszem [title].
Future<void> _choose(WidgetTester tester, String title, String option) async {
  await tester.scrollUntilVisible(find.text(title), 200);
  await _tap(tester, find.text(title));
  await _tap(
    tester,
    find.descendant(of: find.byType(SimpleDialog), matching: find.text(option)),
  );
}

void main() {
  testWidgets('kroki czasu i dystansu z ustawień działają w treningu', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final AppDatabase db = await pumpRepTrack(tester, clock: testClock());

    await _tap(tester, find.byTooltip('Otwórz ustawienia'));
    await _choose(tester, 'Krok czasu', '30 s');
    await _choose(tester, 'Krok dystansu', '250 m');
    expect(find.text('250 m'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('30 s'), -200);
    expect(find.text('30 s'), findsOneWidget);

    final saved = await tester.runAsync(
      () => DriftSettingsRepository(db, testClock()).load(),
    );
    expect((saved!.durationStepSeconds, saved.distanceStepMeters), (30, 250));

    await _tap(tester, find.byTooltip('Wstecz'));
    await _tap(tester, find.text('Pusty trening'));
    await _tap(tester, find.text('Dodaj ćwiczenia'));
    await tester.enterText(find.byType(TextField), 'bieg na biezni');
    await tester.pumpAndSettle();
    await _tap(tester, find.text('Bieg na bieżni'));
    await _tap(tester, find.text('Dodaj (1)'));

    await _tap(tester, find.byTooltip('Zwiększ: Czas'));
    await _tap(tester, find.byTooltip('Zwiększ: Czas'));
    await _tap(tester, find.byTooltip('Zwiększ: Dystans'));

    final session = await tester.runAsync(
      () => DriftWorkoutRepository(db, testClock()).findActive(),
    );
    final set = sortedSets(sortedExercises(session!).single).first;
    expect((set.durationS, set.distanceM), (60, 250));

    await closeRepTrack(tester, db);
  });

  testWidgets('domyślna przerwa „Inna…”', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final db = await pumpRepTrack(tester, seed: false, clock: testClock());

    await _tap(tester, find.byTooltip('Otwórz ustawienia'));
    await _choose(tester, 'Domyślna przerwa', 'Inna…');
    await tester.enterText(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ),
      '2:15',
    );
    await _tap(
      tester,
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Zapisz'),
      ),
    );

    expect(find.text('2:15'), findsOneWidget);
    final saved = await tester.runAsync(
      () => DriftSettingsRepository(db, testClock()).load(),
    );
    expect(saved!.defaultRestSeconds, 135);

    await closeRepTrack(tester, db);
  });
}
