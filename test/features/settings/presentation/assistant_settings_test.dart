import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reptrack/core/database/app_database.dart';
import 'package:reptrack/features/assistant/domain/assistant.dart';
import 'package:reptrack/features/settings/data/drift_settings_repository.dart';
import 'package:reptrack/features/settings/domain/app_settings.dart';

import '../../../support/app_harness.dart';
import '../../../support/fake_devices.dart';
import '../../../support/test_database.dart';

Future<AppDatabase> _launch(
  WidgetTester tester,
  FakeAssistantClient assistant, {
  String? url,
}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final db = widgetTestDatabase();
  if (url != null) {
    await tester.runAsync(
      () => DriftSettingsRepository(
        db,
        testClock(),
      ).save(AppSettings(assistantUrl: url)),
    );
  }
  final app = await pumpRepTrack(
    tester,
    seed: false,
    db: db,
    assistant: assistant,
  );
  await _tap(tester, find.byTooltip('Otwórz ustawienia'));
  await tester.scrollUntilVisible(find.text('Jak podłączyć komputer?'), 300);
  return app;
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<AppSettings> _settings(WidgetTester tester, AppDatabase db) async =>
    (await tester.runAsync(
      () => DriftSettingsRepository(db, testClock()).load(),
    ))!;

void main() {
  testWidgets('adres serwera: walidacja, zapis i wyłączenie', (tester) async {
    final db = await _launch(tester, FakeAssistantClient());

    expect(find.text('Wyłączony. Wpisz adres komputera z Ollamą.'), findsOne);
    await _tap(tester, find.text('Serwer Ollama'));
    await tester.enterText(find.byType(TextField), 'ftp://x');
    await _tap(tester, find.text('Zapisz'));
    expect(find.text('To nie jest poprawny adres.'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '192.168.1.10');
    await _tap(tester, find.text('Zapisz'));
    expect(find.text('http://192.168.1.10:11434'), findsOneWidget);
    expect(
      (await _settings(tester, db)).assistantUrl,
      'http://192.168.1.10:11434',
    );

    await _tap(tester, find.text('Serwer Ollama'));
    await _tap(tester, find.text('Wyłącz'));
    expect(find.text('Wyłączony. Wpisz adres komputera z Ollamą.'), findsOne);
    expect((await _settings(tester, db)).assistantUrl, isNull);

    await closeRepTrack(tester, db);
  });

  testWidgets('test połączenia i wybór modelu', (tester) async {
    final assistant = FakeAssistantClient();
    final db = await _launch(tester, assistant, url: 'http://10.0.2.2:11434');

    await _tap(tester, find.text('Sprawdź połączenie'));
    expect(find.text('Połączono: Ollama 0.40.6, modele: 2'), findsOneWidget);

    await _tap(tester, find.text('Model'));
    await _tap(tester, find.text('qwen3.8:27b'));
    expect(find.text('qwen3.8:27b'), findsOneWidget);
    expect((await _settings(tester, db)).assistantModel, 'qwen3.8:27b');

    await closeRepTrack(tester, db);
  });

  testWidgets('brak połączenia: zrozumiały komunikat', (tester) async {
    final assistant = FakeAssistantClient()
      ..failure = const AssistantException(AssistantFailureKind.unreachable);
    final db = await _launch(tester, assistant, url: 'http://10.0.2.2:11434');

    await _tap(tester, find.text('Sprawdź połączenie'));
    expect(find.textContaining('Brak połączenia z serwerem'), findsOneWidget);

    await _tap(tester, find.text('Model'));
    expect(find.text('qwen3.5:4b'), findsNothing);

    await closeRepTrack(tester, db);
  });

  testWidgets('instrukcja przygotowania komputera', (tester) async {
    final db = await _launch(tester, FakeAssistantClient());

    await _tap(tester, find.text('Jak podłączyć komputer?'));
    expect(find.textContaining('OLLAMA_HOST=0.0.0.0'), findsOneWidget);

    await closeRepTrack(tester, db);
  });
}
