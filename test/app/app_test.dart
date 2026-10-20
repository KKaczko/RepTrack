import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';

void main() {
  testWidgets('dolna nawigacja przełącza pięć zakładek po polsku', (
    tester,
  ) async {
    final db = await pumpRepTrack(tester, seed: false);

    expect(find.text('RepTrack'), findsOneWidget);
    for (final label in [
      'Start',
      'Plan',
      'Szablony',
      'Historia',
      'Ćwiczenia',
    ]) {
      expect(navTab(label), findsOneWidget);
    }

    await tester.tap(navTab('Plan'));
    await tester.pumpAndSettle();
    expect(find.text('Zaplanuj swój tydzień'), findsOneWidget);

    await tester.tap(navTab('Ćwiczenia'));
    await tester.pumpAndSettle();
    expect(find.text('Szukaj ćwiczenia'), findsOneWidget);

    await tester.tap(navTab('Szablony'));
    await tester.pumpAndSettle();
    expect(find.text('Brak szablonów'), findsOneWidget);

    await closeRepTrack(tester, db);
  });

  testWidgets('ustawienia i licencje otwierają się ze Startu i wracają', (
    tester,
  ) async {
    final db = await pumpRepTrack(tester, seed: false);

    await tester.tap(find.byTooltip('Otwórz ustawienia'));
    await tester.pumpAndSettle();
    expect(find.text('Ustawienia'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);

    await tester.scrollUntilVisible(find.text('Licencje i źródła'), 200);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Licencje i źródła'));
    await tester.pumpAndSettle();
    expect(find.textContaining('free-exercise-db'), findsOneWidget);
    expect(find.textContaining('Unlicense'), findsOneWidget);
    expect(find.text('Licencje bibliotek open source'), findsOneWidget);

    await tester.tap(find.byTooltip('Wstecz'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Wstecz'));
    await tester.pumpAndSettle();
    expect(find.byType(NavigationBar), findsOneWidget);

    await closeRepTrack(tester, db);
  });

  testWidgets('układ bez przepełnień przy 360 dp i czcionce 2×', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360 * 3, 740 * 3);
    tester.view.devicePixelRatio = 3;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.reset);

    final db = await pumpRepTrack(tester);
    for (final label in [
      'Plan',
      'Szablony',
      'Historia',
      'Ćwiczenia',
      'Start',
    ]) {
      await tester.tap(navTab(label));
      await tester.pumpAndSettle();
    }
    await tester.tap(navTab('Ćwiczenia'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'sztangi lawce plaskiej');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Wyciskanie sztangi na ławce płaskiej'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    await closeRepTrack(tester, db);
  });

  testWidgets('cele dotyku, etykiety i kontrast na Starcie i w katalogu', (
    tester,
  ) async {
    final db = await pumpRepTrack(tester);

    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));

    await tester.tap(navTab('Ćwiczenia'));
    await tester.pumpAndSettle();
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));

    await closeRepTrack(tester, db);
  });
}
