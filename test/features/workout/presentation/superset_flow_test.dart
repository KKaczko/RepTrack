import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reptrack/core/database/app_database.dart';
import 'package:reptrack/features/exercises/data/drift_exercise_repository.dart';
import 'package:reptrack/features/templates/data/drift_template_repository.dart';
import 'package:reptrack/features/templates/domain/template.dart';
import 'package:reptrack/features/workout/data/drift_workout_repository.dart';
import 'package:reptrack/features/workout/domain/workout_session.dart';

import '../../../support/app_harness.dart';
import '../../../support/test_database.dart';
import '../../../support/workout_fixtures.dart';

/// Aplikacja z „Push A”; [superset] łączy ławkę i podciąganie.
Future<AppDatabase> _launch(WidgetTester tester, {bool superset = true}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final db = widgetTestDatabase();
  await tester.runAsync(() async {
    for (final e in catalog.values) {
      await DriftExerciseRepository(db, testClock()).save(e);
    }
    final template = pushTemplate();
    await DriftTemplateRepository(db, testClock()).save(
      superset
          ? template.copyWith(
              exercises: [
                for (final e in template.exercises) e.copyWith(groupId: 'g'),
              ],
            )
          : template,
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

Future<WorkoutSession> _active(WidgetTester tester, AppDatabase db) async =>
    (await tester.runAsync(
      () => DriftWorkoutRepository(db, testClock()).findActive(),
    ))!;

Future<Template> _template(WidgetTester tester, AppDatabase db) async =>
    (await tester.runAsync(
      () => DriftTemplateRepository(db, testClock()).findById('tpl'),
    ))!;

void main() {
  testWidgets('superseria: na zmianę, przerwa dopiero po rundzie', (
    tester,
  ) async {
    final db = await _launch(tester);
    await _tap(tester, navTab('Szablony'));
    await _tap(tester, find.byTooltip('Rozpocznij trening'));

    expect(find.text('Superseria A · razem z: Podciąganie'), findsOneWidget);
    expect(
      find.bySemanticsLabel(RegExp('Superseria A, ćwiczenie 1')),
      findsOneWidget,
    );

    await _tap(tester, find.text('Zatwierdź serię 1'));
    await tester.pump(const Duration(milliseconds: 400));
    expect((await _active(tester, db)).restEndsAt, isNull);
    expect(find.text('Dalej: Podciąganie'), findsOneWidget);

    await _tap(tester, find.text('Dalej: Podciąganie'));
    expect(find.text('Superseria A · razem z: Wyciskanie'), findsOneWidget);
    await _tap(tester, find.text('Zatwierdź serię 1'));
    await tester.pump(const Duration(milliseconds: 400));

    expect((await _active(tester, db)).restEndsAt, isNotNull);
    expect(find.text('Dalej: Wyciskanie'), findsOneWidget);
    await _tap(tester, find.text('Dalej: Wyciskanie'));
    expect(find.text('Zatwierdź serię 2'), findsOneWidget);

    await closeRepTrack(tester, db);
  });

  testWidgets('edytor szablonu: łączenie i odłączanie superserii', (
    tester,
  ) async {
    final db = await _launch(tester, superset: false);
    await _tap(tester, navTab('Szablony'));
    await _tap(tester, find.text('Push A'));

    await _tap(tester, find.byTooltip('Opcje: Wyciskanie'));
    await _tap(tester, find.text('Połącz w superserię z następnym'));
    expect(
      find.bySemanticsLabel(RegExp('Superseria A, ćwiczenie 1')),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel(RegExp('Superseria A, ćwiczenie 2')),
      findsOneWidget,
    );
    await _tap(tester, find.text('Zapisz'));

    final linked = await _template(tester, db);
    final groups = linked.exercises.map((e) => e.groupId).toSet();
    expect(groups, hasLength(1));
    expect(groups.single, isNotNull);

    await _tap(tester, find.text('Push A'));
    await _tap(tester, find.byTooltip('Opcje: Podciąganie'));
    await _tap(tester, find.text('Odłącz od superserii'));
    expect(find.bySemanticsLabel(RegExp('Superseria')), findsNothing);
    await _tap(tester, find.text('Zapisz'));

    final unlinked = await _template(tester, db);
    expect(unlinked.exercises.map((e) => e.groupId), [null, null]);

    await closeRepTrack(tester, db);
  });

  testWidgets('trening: superseria z menu ⋮', (tester) async {
    final db = await _launch(tester, superset: false);
    await _tap(tester, navTab('Szablony'));
    await _tap(tester, find.byTooltip('Rozpocznij trening'));

    await _tap(tester, find.byTooltip('Opcje treningu'));
    await _tap(tester, find.text('Połącz w superserię z następnym'));

    expect(find.text('Superseria A · razem z: Podciąganie'), findsOneWidget);
    final session = await _active(tester, db);
    expect(session.exercises.map((e) => e.groupId).toSet(), hasLength(1));

    await closeRepTrack(tester, db);
  });
}
