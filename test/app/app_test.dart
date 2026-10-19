import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reptrack/app/app.dart';
import 'package:reptrack/core/database/app_database.dart';
import 'package:reptrack/core/database/database_providers.dart';

import '../support/test_database.dart';

Future<AppDatabase> _pumpApp(WidgetTester tester) async {
  tester.platformDispatcher.localeTestValue = const Locale('pl', 'PL');
  tester.platformDispatcher.localesTestValue = const [Locale('pl', 'PL')];
  addTearDown(tester.platformDispatcher.clearAllTestValues);
  final db = widgetTestDatabase();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
      child: const RepTrackApp(),
    ),
  );
  await tester.pumpAndSettle();
  return db;
}

Future<void> _closeDb(WidgetTester tester, AppDatabase db) async {
  // Zamknięcie drzewa przed bazą, żeby strumienie Drift się zakończyły.
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.runAsync(db.close);
}

void main() {
  testWidgets('dolna nawigacja przełącza cztery zakładki po polsku', (
    tester,
  ) async {
    final db = await _pumpApp(tester);

    expect(find.text('RepTrack'), findsOneWidget);
    for (final label in ['Start', 'Szablony', 'Historia', 'Ćwiczenia']) {
      expect(find.text(label), findsOneWidget);
    }

    await tester.tap(find.text('Ćwiczenia'));
    await tester.pumpAndSettle();
    expect(find.textContaining('bibliotekę ćwiczeń'), findsOneWidget);

    await tester.tap(find.text('Szablony'));
    await tester.pumpAndSettle();
    expect(find.textContaining('szablony treningów'), findsOneWidget);

    await _closeDb(tester, db);
  });

  testWidgets('ustawienia otwierają się ze Startu i wracają', (tester) async {
    final db = await _pumpApp(tester);

    await tester.tap(find.byTooltip('Otwórz ustawienia'));
    await tester.pumpAndSettle();
    expect(find.text('Ustawienia'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);

    await tester.tap(find.byTooltip('Wstecz'));
    await tester.pumpAndSettle();
    expect(find.byType(NavigationBar), findsOneWidget);

    await _closeDb(tester, db);
  });

  testWidgets('układ bez przepełnień przy 360 dp i czcionce 2×', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360 * 3, 740 * 3);
    tester.view.devicePixelRatio = 3;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.reset);

    final db = await _pumpApp(tester);
    for (final label in ['Szablony', 'Historia', 'Ćwiczenia', 'Start']) {
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
    }

    expect(tester.takeException(), isNull);
    await _closeDb(tester, db);
  });

  testWidgets('cele dotyku dolnej nawigacji mają co najmniej 48 dp', (
    tester,
  ) async {
    final db = await _pumpApp(tester);

    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));

    await _closeDb(tester, db);
  });
}
