import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reptrack/core/database/app_database.dart';
import 'package:reptrack/features/exercises/data/drift_exercise_repository.dart';
import 'package:reptrack/features/exercises/domain/exercise.dart';

import '../../../support/app_harness.dart';
import '../../../support/test_database.dart';

Future<AppDatabase> _openLibrary(WidgetTester tester) async {
  final db = await pumpRepTrack(tester);
  await tester.tap(navTab('Ćwiczenia'));
  await tester.pumpAndSettle();
  return db;
}

/// Lista przewijana formularza ćwiczenia (pod nią jest jeszcze katalog).
final _formScroll = find
    .descendant(of: find.byType(Form), matching: find.byType(Scrollable))
    .first;

Future<ExerciseRow?> _rowByName(
  WidgetTester tester,
  AppDatabase db,
  String name,
) => tester.runAsync<ExerciseRow?>(
  () => (db.select(
    db.exercises,
  )..where((t) => t.name.equals(name))).getSingleOrNull(),
);

void main() {
  testWidgets('katalog pokazuje bibliotekę, a wyszukiwanie ignoruje ogonki', (
    tester,
  ) async {
    final db = await _openLibrary(tester);

    expect(find.text('118 ćwiczeń'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'lawce rzymskiej');
    await tester.pumpAndSettle();
    expect(find.text('Wyprosty tułowia na ławce rzymskiej'), findsOneWidget);
    expect(find.text('1 ćwiczenie'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'face pull');
    await tester.pumpAndSettle();
    expect(find.text('Przyciąganie liny do twarzy'), findsOneWidget);

    await tester.tap(find.byTooltip('Wyczyść wyszukiwanie'));
    await tester.pumpAndSettle();
    expect(find.text('118 ćwiczeń'), findsOneWidget);

    await closeRepTrack(tester, db);
  });

  testWidgets('filtr kategorii zawęża listę i pokazuje licznik', (
    tester,
  ) async {
    final db = await _openLibrary(tester);

    await tester.tap(find.byTooltip('Filtry'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.widgetWithText(FilterChip, 'Kardio'),
      200,
      scrollable: find.descendant(
        of: find.byType(BottomSheet),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.tap(find.widgetWithText(FilterChip, 'Kardio'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pokaż wyniki (7)'));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);

    expect(find.text('7 ćwiczeń'), findsOneWidget);
    expect(find.text('Bieg na bieżni'), findsOneWidget);
    expect(find.text('Wyciskanie sztangi na ławce płaskiej'), findsNothing);

    await closeRepTrack(tester, db);
  });

  testWidgets('dodanie własnego ćwiczenia i walidacja formularza', (
    tester,
  ) async {
    final db = await _openLibrary(tester);

    await tester.tap(find.text('Dodaj ćwiczenie'));
    await tester.pumpAndSettle();
    expect(find.text('Nowe ćwiczenie'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);

    final save = find.widgetWithText(FilledButton, 'Zapisz');
    await tester.scrollUntilVisible(save, 300, scrollable: _formScroll);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(find.text('Podaj nazwę ćwiczenia'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Nazwa'),
      -300,
      scrollable: _formScroll,
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Nazwa'),
      'Wiosłowanie na TRX',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Inne nazwy'),
      'TRX row, Wiosłowanie na taśmach',
    );
    await tester.tap(find.widgetWithText(FilterChip, 'Środek pleców').first);
    await tester.pump();
    await tester.scrollUntilVisible(save, 300, scrollable: _formScroll);
    await tester.tap(save);
    await tester.pumpAndSettle();

    expect(find.text('Zapisano ćwiczenie'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'trx');
    await tester.pumpAndSettle();
    expect(find.text('Wiosłowanie na TRX'), findsOneWidget);
    expect(find.text('Własne'), findsOneWidget);

    final row = await _rowByName(tester, db, 'Wiosłowanie na TRX');
    expect(row!.source, ExerciseSource.user);
    expect(row.aliases, ['TRX row', 'Wiosłowanie na taśmach']);
    expect(row.primaryMuscles, [MuscleGroup.middleBack]);
    expect(row.measureWeight && row.measureReps, isTrue);

    await closeRepTrack(tester, db);
  });

  testWidgets('szczegóły pokazują źródło, a edycja wbudowanego ustawia '
      'userModified', (tester) async {
    final db = await _openLibrary(tester);

    await tester.enterText(find.byType(TextField), 'sztangi lawce plaskiej');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Wyciskanie sztangi na ławce płaskiej'));
    await tester.pumpAndSettle();
    expect(find.text('Klatka piersiowa'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Biblioteka wbudowana'), 300);
    expect(find.text('Licencja danych: Unlicense'), findsOneWidget);

    await tester.tap(find.byTooltip('Edytuj'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('aktualizacje biblioteki nie nadpiszą'),
      findsOneWidget,
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Nazwa'),
      'Ławka płaska',
    );
    final save = find.widgetWithText(FilledButton, 'Zapisz');
    await tester.scrollUntilVisible(save, 300, scrollable: _formScroll);
    await tester.tap(save);
    await tester.pumpAndSettle();

    // Szczegóły były przewinięte do sekcji „Źródło”; wracamy do nagłówka.
    await tester.scrollUntilVisible(find.text('Ławka płaska'), -300);
    expect(find.text('Ławka płaska'), findsOneWidget);
    final row = await _rowByName(tester, db, 'Ławka płaska');
    expect(row!.userModified, isTrue);
    expect(row.source, ExerciseSource.builtin);
    await tester.scrollUntilVisible(
      find.textContaining('Zmienione przez Ciebie'),
      300,
    );
    expect(find.textContaining('Zmienione przez Ciebie'), findsOneWidget);

    await closeRepTrack(tester, db);
  });

  testWidgets('archiwizacja ukrywa ćwiczenie, a filtr archiwum je pokazuje', (
    tester,
  ) async {
    final db = await _openLibrary(tester);

    await tester.tap(find.text('Arnoldki'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Więcej akcji'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Archiwizuj'));
    await tester.pumpAndSettle();
    expect(find.text('Ćwiczenie przeniesione do archiwum'), findsOneWidget);
    expect(find.text('W archiwum'), findsOneWidget);

    await tester.tap(find.byTooltip('Wstecz'));
    await tester.pumpAndSettle();
    expect(find.text('117 ćwiczeń'), findsOneWidget);
    expect(find.text('Arnoldki'), findsNothing);

    await tester.tap(find.byTooltip('Filtry'));
    await tester.pumpAndSettle();
    final archivedSwitch = find.widgetWithText(
      SwitchListTile,
      'Tylko zarchiwizowane',
    );
    await tester.scrollUntilVisible(
      archivedSwitch,
      300,
      scrollable: find.descendant(
        of: find.byType(BottomSheet),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.tap(archivedSwitch);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pokaż wyniki (1)'));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
    expect(find.text('Arnoldki'), findsOneWidget);

    await closeRepTrack(tester, db);
  });

  testWidgets('wbudowanego ćwiczenia nie da się usunąć, własne nieużyte tak', (
    tester,
  ) async {
    final db = await _openLibrary(tester);
    await tester.runAsync(
      () => DriftExerciseRepository(
        db,
        testClock(),
      ).save(testExercise('own', name: 'Moje ćwiczenie testowe')),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Arnoldki'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Więcej akcji'));
    await tester.pumpAndSettle();
    expect(find.text('Usuń'), findsNothing);
    await tester.tapAt(Offset.zero);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Wstecz'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'testowe');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Moje ćwiczenie testowe'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Więcej akcji'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Usuń'));
    await tester.pumpAndSettle();
    expect(find.text('Usunąć ćwiczenie?'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Usuń'));
    await tester.pumpAndSettle();

    expect(find.text('Ćwiczenie usunięte'), findsOneWidget);
    expect(find.text('Moje ćwiczenie testowe'), findsNothing);
    expect(find.text('Brak wyników'), findsOneWidget);

    await closeRepTrack(tester, db);
  });
}
