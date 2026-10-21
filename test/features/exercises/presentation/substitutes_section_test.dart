import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/app_harness.dart';

const _machine = 'Wyciskanie na maszynie siedząc';
const _dumbbell = 'Wyciskanie hantli na ławce płaskiej';

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// Lista zakładki Info ekranu ćwiczenia.
Finder get _info => find
    .descendant(
      of: find.byKey(const PageStorageKey('exercise-info')),
      matching: find.byType(Scrollable),
    )
    .first;

void main() {
  testWidgets('ekran ćwiczenia: zamienniki, przypięcie i przejście', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final db = await pumpRepTrack(tester);

    await _tap(tester, navTab('Ćwiczenia'));
    await tester.enterText(find.byType(TextField), 'maszynie siedzac');
    await tester.pumpAndSettle();
    await _tap(tester, find.text(_machine));

    await tester.scrollUntilVisible(
      find.text('Zamienniki'),
      300,
      scrollable: _info,
    );
    await tester.scrollUntilVisible(
      find.byTooltip('Przypnij zamiennik: $_dumbbell'),
      200,
      scrollable: _info,
    );
    await _tap(tester, find.byTooltip('Przypnij zamiennik: $_dumbbell'));
    expect(find.byTooltip('Odepnij zamiennik: $_dumbbell'), findsOneWidget);
    expect(find.textContaining('przypięty'), findsOneWidget);

    await _tap(tester, find.text(_dumbbell));
    expect(find.text(_dumbbell), findsWidgets);
    // Para działa w obie strony: na ekranie zamiennika maszyna jest przypięta.
    await tester.scrollUntilVisible(
      find.byTooltip('Odepnij zamiennik: $_machine'),
      300,
      scrollable: _info,
    );
    expect(find.byTooltip('Odepnij zamiennik: $_machine'), findsOneWidget);

    await closeRepTrack(tester, db);
  });
}
