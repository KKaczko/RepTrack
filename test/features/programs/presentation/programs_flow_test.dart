import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reptrack/core/database/app_database.dart';
import 'package:reptrack/core/domain/local_date.dart';
import 'package:reptrack/features/plan/data/drift_plan_repository.dart';
import 'package:reptrack/features/plan/domain/plan.dart';
import 'package:reptrack/features/templates/data/drift_template_repository.dart';

import '../../../support/app_harness.dart';
import '../../../support/test_database.dart';

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// Czysta instalacja z prawdziwą biblioteką ćwiczeń (poniedziałek
/// 19.10.2026).
Future<AppDatabase> _launch(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  return pumpRepTrack(tester, clock: testClock());
}

void main() {
  testWidgets('Start bez szablonów → program → „Dziś wg planu”', (
    tester,
  ) async {
    final db = await _launch(tester);

    expect(find.text('Zacznij od gotowego programu'), findsOneWidget);
    await _tap(tester, find.text('Wybierz program'));
    expect(find.text('Gotowe programy'), findsOneWidget);

    await _tap(tester, find.widgetWithText(FilterChip, '2×'));
    expect(find.text('FBW 2× w tygodniu (mało czasu)'), findsOneWidget);
    expect(find.text('Góra/Dół (4× w tygodniu)'), findsNothing);

    await _tap(tester, find.text('FBW 2× w tygodniu (mało czasu)'));
    expect(find.text('Plan tygodnia'), findsOneWidget);
    expect(find.text('Poniedziałek: FBW 2× A'), findsOneWidget);
    expect(find.text('Czwartek: FBW 2× B'), findsOneWidget);

    await _tap(tester, find.text('Dodaj program'));

    expect(
      find.text('Dodano program: FBW 2× w tygodniu (mało czasu)'),
      findsOne,
    );
    expect(find.text('Dziś wg planu: FBW 2× A'), findsOneWidget);
    final templates = await tester.runAsync(
      () => DriftTemplateRepository(db, testClock()).watchAll().first,
    );
    expect([for (final t in templates!) t.name]..sort(), [
      'FBW 2× A',
      'FBW 2× B',
    ]);
    final plan = await tester.runAsync(
      () => DriftPlanRepository(db, testClock()).load(),
    );
    expect(plan!.weekly.single.days.map((d) => d.weekday), [1, 4]);

    await closeRepTrack(tester, db);
  });

  testWidgets('istniejący plan tygodnia: pytanie przed zastąpieniem', (
    tester,
  ) async {
    final db = await _launch(tester);
    await tester.runAsync(
      () => DriftPlanRepository(db, testClock()).saveWeekly(
        save: const [
          WeeklyPlan(id: 'old', startsOn: LocalDate(2026, 10, 5), days: []),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await _tap(tester, find.text('Wybierz program'));
    await _tap(tester, find.text('Siła 5×5'));
    await _tap(tester, find.text('Dodaj program'));
    expect(find.text('Zastąpić plan tygodnia?'), findsOneWidget);
    await _tap(tester, find.text('Anuluj'));
    final before = await tester.runAsync(
      () => DriftTemplateRepository(db, testClock()).watchAll().first,
    );
    expect(before, isEmpty);

    await _tap(tester, find.text('Dodaj program'));
    await _tap(tester, find.text('Zastąp'));
    expect(find.text('Dziś wg planu: 5×5 A'), findsOneWidget);

    await closeRepTrack(tester, db);
  });

  testWidgets('Szablony: akcja „Gotowe programy” w pasku', (tester) async {
    final db = await _launch(tester);

    await _tap(tester, navTab('Szablony'));
    await _tap(tester, find.byTooltip('Gotowe programy'));
    await tester.scrollUntilVisible(
      find.text('Hantle w domu (3× w tygodniu)'),
      300,
    );
    expect(find.text('Hantle w domu (3× w tygodniu)'), findsOneWidget);

    await closeRepTrack(tester, db);
  });
}
