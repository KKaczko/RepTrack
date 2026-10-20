import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reptrack/core/database/app_database.dart';
import 'package:reptrack/core/domain/local_date.dart';
import 'package:reptrack/features/exercises/data/drift_exercise_repository.dart';
import 'package:reptrack/features/plan/data/drift_plan_repository.dart';
import 'package:reptrack/features/plan/domain/plan.dart';
import 'package:reptrack/features/settings/data/drift_settings_repository.dart';
import 'package:reptrack/features/settings/domain/app_settings.dart';
import 'package:reptrack/features/templates/data/drift_template_repository.dart';
import 'package:reptrack/features/workout/data/drift_workout_repository.dart';

import '../support/app_harness.dart';
import '../support/test_database.dart';
import '../support/workout_fixtures.dart';

/// Przegląd dostępności (Etap 7): układ przy 360 dp i czcionce 2×, cele
/// dotyku, etykiety i kontrast na ekranach treningu, historii, progresu,
/// ustawień, kopii, słowniczka i asystenta, w ciemnym i jasnym motywie.

/// Aplikacja z szablonem i zakończonym treningiem.
Future<AppDatabase> _launch(
  WidgetTester tester, {
  double textScale = 1,
  AppThemeMode theme = AppThemeMode.dark,
}) async {
  tester.view.physicalSize = const Size(360 * 3, 740 * 3);
  tester.view.devicePixelRatio = 3;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
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
    await DriftSettingsRepository(db, testClock()).save(
      AppSettings(themeMode: theme, assistantUrl: 'http://10.0.2.2:11434'),
    );
    // Plan: poniedziałki „Push A” od 5.10 (12.10 zrobiony, 19.10 dziś).
    await DriftPlanRepository(db, testClock()).saveWeekly(
      save: const [
        WeeklyPlan(
          id: 'wp',
          startsOn: LocalDate(2026, 10, 5),
          days: [
            WeeklyPlanDay(id: 'd', weekday: 1, templateId: 'tpl', position: 0),
          ],
        ),
      ],
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

/// Lista zakładki Progres (zakładki historii mają kilka list naraz).
final _progressList = find
    .descendant(
      of: find.byKey(const PageStorageKey('progress')),
      matching: find.byType(Scrollable),
    )
    .first;

Future<void> _meetsGuidelines(WidgetTester tester) async {
  await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
  await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
  await expectLater(tester, meetsGuideline(textContrastGuideline));
}

void main() {
  testWidgets('czcionka 2× na 360 dp: trening, historia, progres', (
    tester,
  ) async {
    final db = await _launch(tester, textScale: 2);

    await _tap(tester, find.text('Dziś wg planu: Push A'));
    expect(tester.takeException(), isNull);
    await _tap(tester, find.byTooltip('Zwiększ: Ciężar'));
    await _tap(tester, find.byKey(const ValueKey('workout-value-reps')));
    expect(tester.takeException(), isNull);
    await _tap(tester, find.text('8'));
    await _tap(tester, find.byTooltip('Opcje treningu'));
    await _tap(tester, find.text('Zakończ trening'));
    expect(tester.takeException(), isNull);
    await _tap(tester, find.byTooltip('Wstecz'));
    await _tap(tester, find.byTooltip('Zminimalizuj trening'));

    await _tap(tester, find.text('Historia'));
    await _tap(tester, find.text('Push A').first);
    expect(tester.takeException(), isNull);
    await _tap(tester, find.byTooltip('Porównaj z poprzednim'));
    expect(tester.takeException(), isNull);
    await _tap(tester, find.byTooltip('Wstecz'));
    await _tap(tester, find.byTooltip('Wstecz'));

    await _tap(tester, find.text('Progres'));
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(
      find.text('Treningi z ćwiczeniem'),
      300,
      scrollable: _progressList,
    );
    expect(tester.takeException(), isNull);

    await closeRepTrack(tester, db);
  });

  testWidgets('czcionka 2× na 360 dp: ustawienia, kopia, słowniczek', (
    tester,
  ) async {
    final db = await _launch(tester, textScale: 2);

    await _tap(tester, find.byTooltip('Otwórz ustawienia'));
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(find.text('Kopia i eksport'), 300);
    await _tap(tester, find.text('Kopia i eksport'));
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(find.text('Markdown'), 300);
    await _tap(tester, find.text('Markdown'));
    expect(tester.takeException(), isNull);
    await _tap(tester, find.byTooltip('Wstecz'));

    await tester.scrollUntilVisible(find.text('Słowniczek pojęć'), 300);
    await _tap(tester, find.text('Słowniczek pojęć'));
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(find.text('Progresja'), 300);
    expect(tester.takeException(), isNull);
    await _tap(tester, find.byTooltip('Wstecz'));
    await _tap(tester, find.byTooltip('Wstecz'));

    await _tap(tester, find.byTooltip('Asystent AI'));
    expect(tester.takeException(), isNull);
    await _tap(tester, find.text('Jak mi idzie w ostatnim miesiącu?'));
    expect(tester.takeException(), isNull);

    await closeRepTrack(tester, db);
  });

  testWidgets('czcionka 2× na 360 dp: plan, widok tygodnia, edytor', (
    tester,
  ) async {
    final db = await _launch(tester, textScale: 2);

    await _tap(tester, navTab('Plan'));
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(find.text('Rozpocznij'), 300);
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(find.text('Tydzień'), -300);
    await _tap(tester, find.text('Tydzień'));
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(find.text('Ten tydzień'), -300);
    await _tap(tester, find.byTooltip('Edytuj plan tygodnia'));
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(find.text('Niedziela'), 300);
    expect(tester.takeException(), isNull);

    await closeRepTrack(tester, db);
  });

  for (final theme in [AppThemeMode.dark, AppThemeMode.light]) {
    testWidgets('cele dotyku, etykiety i kontrast: ${theme.code}', (
      tester,
    ) async {
      final db = await _launch(tester, theme: theme);

      await _meetsGuidelines(tester);
      await _tap(tester, find.text('Dziś wg planu: Push A'));
      await _meetsGuidelines(tester);
      await _tap(tester, find.text('Zatwierdź serię 1'));
      await tester.pump(const Duration(milliseconds: 400));
      await _meetsGuidelines(tester);
      await _tap(tester, find.byTooltip('Zminimalizuj trening'));

      await _tap(tester, find.text('Historia'));
      await _meetsGuidelines(tester);
      await _tap(tester, find.text('Push A').first);
      await _meetsGuidelines(tester);
      await _tap(tester, find.byTooltip('Wstecz'));

      await _tap(tester, find.text('Progres'));
      await _meetsGuidelines(tester);
      await tester.scrollUntilVisible(
        find.text('Treningi z ćwiczeniem'),
        300,
        scrollable: _progressList,
      );
      await _meetsGuidelines(tester);

      await _tap(
        tester,
        find.byIcon(Icons.info_outline_rounded).hitTestable().first,
      );
      await _meetsGuidelines(tester);
      await _tap(tester, find.text('Wszystkie pojęcia'));
      await _meetsGuidelines(tester);
      await _tap(tester, find.byTooltip('Wstecz'));

      await _tap(tester, navTab('Plan'));
      await _meetsGuidelines(tester);
      await _tap(tester, find.text('Tydzień'));
      await _meetsGuidelines(tester);
      await _tap(tester, find.byTooltip('Edytuj plan tygodnia'));
      await _meetsGuidelines(tester);
      await _tap(tester, find.byTooltip('Wstecz'));

      await _tap(tester, navTab('Start'));
      await _tap(tester, find.byTooltip('Asystent AI'));
      await _meetsGuidelines(tester);
      await _tap(tester, find.text('Jak mi idzie w ostatnim miesiącu?'));
      await _meetsGuidelines(tester);

      await closeRepTrack(tester, db);
    });
  }
}
