import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reptrack/core/database/app_database.dart';
import 'package:reptrack/features/exercises/data/drift_exercise_repository.dart';
import 'package:reptrack/features/templates/data/drift_template_repository.dart';
import 'package:reptrack/features/templates/domain/set_plan.dart';
import 'package:reptrack/features/templates/domain/template.dart';
import 'package:reptrack/features/templates/domain/template_editing.dart';

import '../../../support/app_harness.dart';
import '../../../support/fakes.dart';
import '../../../support/test_database.dart';

Future<AppDatabase> _openTemplates(WidgetTester tester) async {
  final db = await pumpRepTrack(tester);
  await tester.tap(navTab('Szablony'));
  await tester.pumpAndSettle();
  return db;
}

Future<List<Template>> _templates(WidgetTester tester, AppDatabase db) async =>
    (await tester.runAsync(
      () => DriftTemplateRepository(
        db,
        testClock(),
      ).watchAll(includeArchived: true).first,
    ))!;

/// Dodaje do bazy szablon „Push A” z dwoma ćwiczeniami z biblioteki.
Future<void> _seedTemplate(WidgetTester tester, AppDatabase db) async {
  await tester.runAsync(() async {
    final exercises = DriftExerciseRepository(db, testClock());
    final all = await exercises.watchAll().first;
    final picked = [
      all.firstWhere((e) => e.name == 'Arnoldki'),
      all.firstWhere((e) => e.name == 'Wyciskanie sztangi na ławce płaskiej'),
    ];
    await DriftTemplateRepository(db, testClock()).save(
      addExercises(
        const Template(id: 'tpl', name: 'Push A'),
        picked,
        SequentialIds('s'),
      ),
    );
  });
  await tester.pumpAndSettle();
}

Finder _inSet(int number, Finder matching) => find.descendant(
  of: find.widgetWithText(ExpansionTile, 'Seria $number'),
  matching: matching,
);

/// Przewija arkusz konfiguracji ćwiczenia, aż [finder] będzie cały widoczny.
Future<void> _scrollSheetTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    150,
    scrollable: find
        .descendant(
          of: find.byType(BottomSheet),
          matching: find.byType(Scrollable),
        )
        .first,
  );
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('tworzenie szablonu z wyborem ćwiczeń i nadpisaniem serii', (
    tester,
  ) async {
    final db = await _openTemplates(tester);
    expect(find.text('Brak szablonów'), findsOneWidget);

    await tester.tap(find.text('Nowy szablon'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Nazwa szablonu'),
      'Push A',
    );

    await tester.tap(find.text('Dodaj ćwiczenia'));
    await tester.pumpAndSettle();
    expect(find.text('Wybierz ćwiczenia'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'arnold');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Arnoldki'));
    await tester.enterText(find.byType(TextField), 'sztangi lawce plaskiej');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Wyciskanie sztangi na ławce płaskiej'));
    await tester.pump();
    await tester.tap(find.text('Dodaj (2)'));
    await tester.pumpAndSettle();

    expect(find.text('Arnoldki'), findsOneWidget);
    expect(find.text('3 × 8–12'), findsNWidgets(2));

    // Konfiguracja: 4 serie, ostatnia z własnym zakresem 6–8.
    await tester.tap(find.text('Arnoldki'));
    await tester.pumpAndSettle();
    await _scrollSheetTo(tester, find.byTooltip('Więcej serii'));
    await tester.tap(find.byTooltip('Więcej serii'));
    await tester.pumpAndSettle();
    final set4 = find.widgetWithText(ExpansionTile, 'Seria 4');
    await _scrollSheetTo(tester, set4);
    await tester.tap(set4);
    await tester.pumpAndSettle();
    await tester.enterText(
      _inSet(4, find.widgetWithText(TextField, 'Od')),
      '6',
    );
    await tester.enterText(
      _inSet(4, find.widgetWithText(TextField, 'Do')),
      '8',
    );
    await tester.pump();
    expect(find.textContaining('6–8 · Robocza · zmienione'), findsOneWidget);
    await tester.tap(find.text('Gotowe'));
    await tester.pumpAndSettle();

    expect(find.text('4 serie: 8–12 / 8–12 / 8–12 / 6–8'), findsOneWidget);
    await tester.tap(find.text('Zapisz'));
    await tester.pumpAndSettle();

    expect(find.text('Push A'), findsOneWidget);
    expect(find.text('2 ćwiczenia · 7 serii'), findsOneWidget);

    // Snackbar „Zapisano szablon” nie zasłania przycisku „Nowy szablon”
    // (zasłonięte stuknięcie kończy test błędem, flutter_test_config.dart).
    expect(find.text('Zapisano szablon'), findsOneWidget);
    await tester.tap(find.text('Nowy szablon'));
    await tester.pumpAndSettle();
    expect(find.text('Nazwa szablonu'), findsOneWidget);
    await tester.tap(find.byTooltip('Zamknij'));
    await tester.pumpAndSettle();
    final saved = (await _templates(tester, db)).single;
    final arnold = resolveEffectiveSets(saved.exercises.first);
    expect(
      [for (final s in arnold) (s.targetMin, s.targetMax)],
      [(8, 12), (8, 12), (8, 12), (6, 8)],
    );
    expect(arnold.last.overridesTarget, isTrue);

    await closeRepTrack(tester, db);
  });

  testWidgets('przywrócenie dziedziczenia usuwa nadpisanie serii', (
    tester,
  ) async {
    final db = await _openTemplates(tester);
    await _seedTemplate(tester, db);

    await tester.tap(find.text('Push A'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Arnoldki'));
    await tester.pumpAndSettle();
    await _scrollSheetTo(tester, find.widgetWithText(ExpansionTile, 'Seria 1'));
    await tester.tap(find.widgetWithText(ExpansionTile, 'Seria 1'));
    await tester.pumpAndSettle();
    await _scrollSheetTo(tester, find.text('Przywróć dziedziczenie'));
    await tester.enterText(
      _inSet(1, find.widgetWithText(TextField, 'Do')),
      '5',
    );
    await tester.pump();
    expect(find.textContaining('zmienione'), findsOneWidget);
    expect(find.textContaining('minimum nie może być większe'), findsOneWidget);

    await _scrollSheetTo(tester, find.text('Przywróć dziedziczenie'));
    await tester.tap(find.text('Przywróć dziedziczenie'));
    await tester.pumpAndSettle();
    expect(find.textContaining('zmienione'), findsNothing);
    expect(find.textContaining('minimum nie może być większe'), findsNothing);

    await tester.tap(find.text('Gotowe'));
    await tester.pumpAndSettle();
    expect(find.text('3 × 8–12'), findsNWidgets(2));

    await closeRepTrack(tester, db);
  });

  testWidgets('zmiana kolejności przeciąganiem uchwytu', (tester) async {
    final db = await _openTemplates(tester);
    await _seedTemplate(tester, db);

    await tester.tap(find.text('Push A'));
    await tester.pumpAndSettle();
    double top(String name) => tester.getTopLeft(find.text(name)).dy;
    expect(
      top('Arnoldki'),
      lessThan(top('Wyciskanie sztangi na ławce płaskiej')),
    );

    // Pierwszy uchwyt należy do „Arnoldki” (pierwsze ćwiczenie).
    final handle = find.byIcon(Icons.drag_handle_rounded).first;
    final gesture = await tester.startGesture(tester.getCenter(handle));
    await tester.pump(const Duration(milliseconds: 50));
    await gesture.moveBy(const Offset(0, 120));
    await tester.pump();
    await gesture.moveBy(const Offset(0, 120));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(
      top('Arnoldki'),
      greaterThan(top('Wyciskanie sztangi na ławce płaskiej')),
    );
    await tester.tap(find.text('Zapisz'));
    await tester.pumpAndSettle();
    final saved = (await _templates(tester, db)).single;
    expect(
      saved.exercises.first.exerciseId,
      isNot('arnold'),
      reason: 'zapisana kolejność: wyciskanie, potem arnoldki',
    );
    expect(saved.exercises.last.position, 1);

    await closeRepTrack(tester, db);
  });

  testWidgets('duplikowanie, archiwum i usuwanie z menu', (tester) async {
    final db = await _openTemplates(tester);
    await _seedTemplate(tester, db);

    await tester.tap(find.byTooltip('Akcje szablonu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Duplikuj'));
    await tester.pumpAndSettle();
    expect(find.text('Push A (kopia)'), findsOneWidget);

    await tester.tap(find.byTooltip('Akcje szablonu').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Archiwizuj'));
    await tester.pumpAndSettle();
    expect(find.text('Push A (kopia)'), findsNothing);

    await tester.tap(find.byTooltip('Pokaż archiwum'));
    await tester.pumpAndSettle();
    expect(find.text('Push A (kopia)'), findsOneWidget);
    await tester.tap(find.byTooltip('Akcje szablonu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Usuń'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Usuń'));
    await tester.pumpAndSettle();
    expect(find.text('Archiwum jest puste.'), findsOneWidget);

    final all = await _templates(tester, db);
    expect([for (final t in all) t.name], ['Push A']);

    await closeRepTrack(tester, db);
  });

  testWidgets('walidacja nazwy i potwierdzenie porzucenia zmian', (
    tester,
  ) async {
    final db = await _openTemplates(tester);

    await tester.tap(find.text('Nowy szablon'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Zapisz'));
    await tester.pumpAndSettle();
    expect(find.text('Podaj nazwę szablonu'), findsWidgets);

    await tester.enterText(
      find.widgetWithText(TextField, 'Nazwa szablonu'),
      'Nogi',
    );
    await tester.tap(find.byTooltip('Zamknij'));
    await tester.pumpAndSettle();
    expect(find.text('Odrzucić zmiany w szablonie?'), findsOneWidget);
    await tester.tap(find.text('Odrzuć'));
    await tester.pumpAndSettle();

    expect(find.text('Brak szablonów'), findsOneWidget);
    expect(await _templates(tester, db), isEmpty);

    await closeRepTrack(tester, db);
  });
}
