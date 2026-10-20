import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reptrack/core/database/app_database.dart';
import 'package:reptrack/features/assistant/domain/assistant.dart';
import 'package:reptrack/core/domain/local_date.dart';
import 'package:reptrack/features/exercises/data/drift_exercise_repository.dart';
import 'package:reptrack/features/plan/data/drift_plan_repository.dart';
import 'package:reptrack/features/plan/domain/plan.dart';
import 'package:reptrack/features/settings/data/drift_settings_repository.dart';
import 'package:reptrack/features/settings/domain/app_settings.dart';
import 'package:reptrack/features/templates/data/drift_template_repository.dart';
import 'package:reptrack/features/workout/data/drift_workout_repository.dart';

import '../../../support/app_harness.dart';
import '../../../support/fake_devices.dart';
import '../../../support/test_database.dart';
import '../../../support/workout_fixtures.dart';

/// Aplikacja z szablonem, dwoma treningami i (domyślnie) ustawionym
/// serwerem asystenta.
Future<AppDatabase> _launch(
  WidgetTester tester,
  FakeAssistantClient assistant, {
  bool configured = true,
  bool withPlan = false,
}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final db = widgetTestDatabase();
  await tester.runAsync(() async {
    for (final e in catalog.values) {
      await DriftExerciseRepository(db, testClock()).save(e);
    }
    await DriftTemplateRepository(db, testClock()).save(pushTemplate());
    final workouts = DriftWorkoutRepository(db, testClock());
    await workouts.save(
      finishedPush('b', DateTime.utc(2026, 10, 12, 16), [
        (80000, 10),
        (80000, 9),
      ]),
    );
    await workouts.save(
      finishedPush('c', DateTime.utc(2026, 10, 19, 16), [
        (85000, 8),
        (85000, 7),
      ]),
    );
    if (withPlan) {
      await DriftPlanRepository(db, testClock()).saveWeekly(
        save: const [
          WeeklyPlan(
            id: 'wp',
            startsOn: LocalDate(2026, 10, 5),
            days: [
              WeeklyPlanDay(
                id: 'd',
                weekday: 1,
                templateId: 'tpl',
                position: 0,
              ),
            ],
          ),
        ],
      );
    }
    if (configured) {
      await DriftSettingsRepository(
        db,
        testClock(),
      ).save(const AppSettings(assistantUrl: 'http://10.0.2.2:11434'));
    }
  });
  return pumpRepTrack(
    tester,
    seed: false,
    db: db,
    clock: testClock(),
    assistant: assistant,
  );
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _openAssistant(WidgetTester tester) =>
    _tap(tester, find.byTooltip('Asystent AI'));

void main() {
  testWidgets('bez konfiguracji: zachęta i przejście do ustawień', (
    tester,
  ) async {
    final db = await _launch(tester, FakeAssistantClient(), configured: false);

    await _openAssistant(tester);
    expect(find.text('Podłącz asystenta'), findsOneWidget);
    await _tap(tester, find.text('Otwórz ustawienia'));
    await tester.scrollUntilVisible(find.text('Serwer Ollama'), 300);
    expect(find.text('Wyłączony. Wpisz adres komputera z Ollamą.'), findsOne);

    await closeRepTrack(tester, db);
  });

  testWidgets('podpowiedź: dane z aplikacji w kontekście i odpowiedź', (
    tester,
  ) async {
    final assistant = FakeAssistantClient()
      ..reply = ['**Dobrze** idzie:\n', '- Wyciskanie +0,9%'];
    final db = await _launch(tester, assistant);

    await _openAssistant(tester);
    await _tap(tester, find.text('Jak mi idzie w ostatnim miesiącu?'));

    expect(find.text('Dobrze idzie:'), findsOneWidget);
    expect(find.text('Wyciskanie +0,9%'), findsOneWidget);
    final chat = assistant.chats.single;
    expect(chat.server, Uri.parse('http://10.0.2.2:11434'));
    // Bez wybranego modelu: pierwszy z serwera.
    expect(chat.model, 'qwen3.5:4b');
    expect(chat.messages.first.role, ChatRole.system);
    expect(chat.messages.first.content, contains('Dane treningowe z RepTrack'));
    expect(
      chat.messages.first.content,
      contains('- Wyciskanie: Szacowany 1RM 107,7 kg'),
    );
    expect(chat.messages.last, (
      role: ChatRole.user,
      content: 'Jak mi idzie w ostatnim miesiącu?',
    ));

    await closeRepTrack(tester, db);
  });

  testWidgets('własne pytanie: model dostaje wcześniejszą rozmowę', (
    tester,
  ) async {
    final assistant = FakeAssistantClient();
    final db = await _launch(tester, assistant);

    await _openAssistant(tester);
    await tester.enterText(find.byType(TextField), 'Ile trenuję?');
    await _tap(tester, find.byTooltip('Wyślij'));
    await tester.enterText(find.byType(TextField), 'A w tym tygodniu?');
    await _tap(tester, find.byTooltip('Wyślij'));

    expect(find.text('Dobra robota!'), findsNWidgets(2));
    final second = assistant.chats.last.messages;
    expect(
      [for (final m in second) m.role],
      [ChatRole.system, ChatRole.user, ChatRole.assistant, ChatRole.user],
    );
    expect(second[2].content, 'Dobra robota!');
    expect(second[3].content, 'A w tym tygodniu?');

    await closeRepTrack(tester, db);
  });

  testWidgets('zatrzymanie odpowiedzi w trakcie', (tester) async {
    final live = StreamController<String>();
    addTearDown(live.close);
    final assistant = FakeAssistantClient()..live = live;
    final db = await _launch(tester, assistant);

    await _openAssistant(tester);
    await tester.enterText(find.byType(TextField), 'Pytanie');
    // Wskaźnik oczekiwania kręci się bez końca: bez pumpAndSettle.
    await tester.tap(find.byTooltip('Wyślij'));
    await tester.pump();
    await tester.pump();
    expect(find.text('Asystent analizuje dane…'), findsOneWidget);

    live.add('Częściowa odpowiedź');
    await tester.pump();
    expect(find.text('Częściowa odpowiedź'), findsOneWidget);
    expect(find.text('Asystent analizuje dane…'), findsNothing);

    await _tap(tester, find.byTooltip('Zatrzymaj'));
    expect(find.text('Zatrzymano.'), findsOneWidget);
    expect(find.byTooltip('Wyślij'), findsOneWidget);

    await closeRepTrack(tester, db);
  });

  testWidgets('brak połączenia: komunikat i ponowienie', (tester) async {
    final assistant = FakeAssistantClient()
      ..failure = const AssistantException(AssistantFailureKind.unreachable);
    final db = await _launch(tester, assistant);

    await _openAssistant(tester);
    await _tap(tester, find.text('Które partie mięśniowe zaniedbuję?'));
    expect(find.textContaining('Brak połączenia z serwerem'), findsOneWidget);

    assistant.failure = null;
    await _tap(tester, find.text('Spróbuj ponownie'));
    expect(find.textContaining('Brak połączenia'), findsNothing);
    expect(find.text('Dobra robota!'), findsOneWidget);

    await closeRepTrack(tester, db);
  });

  testWidgets('„Podsumuj z AI” w szczegółach treningu', (tester) async {
    final assistant = FakeAssistantClient();
    final db = await _launch(tester, assistant);

    await _tap(tester, navTab('Historia'));
    await _tap(tester, find.text('Push A').first);
    await _tap(tester, find.byTooltip('Więcej akcji'));
    await _tap(tester, find.text('Podsumuj z AI'));

    expect(find.textContaining('Podsumuj trening „Push A”'), findsOneWidget);
    final chat = assistant.chats.single;
    expect(chat.messages.first.content, contains('# Trening do omówienia'));
    expect(chat.messages.first.content, contains('2026-10-19'));
    expect(chat.messages.last.content, startsWith('Skomentuj ten trening'));
    expect(find.text('Dobra robota!'), findsOneWidget);

    await closeRepTrack(tester, db);
  });

  testWidgets('„Propozycja AI” w menu szablonu', (tester) async {
    final assistant = FakeAssistantClient();
    final db = await _launch(tester, assistant);

    await _tap(tester, navTab('Szablony'));
    await _tap(tester, find.byTooltip('Akcje szablonu'));
    await _tap(tester, find.text('Propozycja AI'));

    expect(find.text('Zaproponuj następny trening „Push A”'), findsOneWidget);
    final sent = assistant.chats.single.messages.last.content;
    expect(sent, startsWith('Zaproponuj następny trening „Push A”.'));
    expect(sent, contains('# Szablon: Push A'));
    expect(sent, contains('- 2026-10-19: 85×8, 85×7'));

    await closeRepTrack(tester, db);
  });

  testWidgets('podpowiedź propozycji: wybór szablonu', (tester) async {
    final assistant = FakeAssistantClient();
    final db = await _launch(tester, assistant);

    await _openAssistant(tester);
    await _tap(tester, find.text('Zaproponuj następny trening'));
    expect(find.text('Wybierz szablon'), findsOneWidget);
    await _tap(tester, find.text('Push A'));

    expect(
      assistant.chats.single.messages.last.content,
      contains('# Szablon: Push A'),
    );

    await closeRepTrack(tester, db);
  });

  testWidgets('z planem: podpowiedź o plan i sekcja planu w kontekście', (
    tester,
  ) async {
    final assistant = FakeAssistantClient();
    final db = await _launch(tester, assistant, withPlan: true);

    await _openAssistant(tester);
    await _tap(tester, find.text('Jak realizuję plan?'));

    final system = assistant.chats.single.messages.first.content;
    expect(system, contains('## Plan treningów'));
    expect(system, contains('Poniedziałek 2026-10-19: Push A (Zrobiony)'));

    await closeRepTrack(tester, db);
  });
}
