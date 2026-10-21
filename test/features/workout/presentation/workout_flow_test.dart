import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:reptrack/app/routes.dart';
import 'package:reptrack/core/database/app_database.dart';
import 'package:reptrack/features/exercises/data/drift_exercise_repository.dart';
import 'package:reptrack/features/templates/data/drift_template_repository.dart';
import 'package:reptrack/features/workout/data/drift_workout_repository.dart';
import 'package:reptrack/features/workout/data/workout_providers.dart';
import 'package:reptrack/features/workout/domain/session_builder.dart';
import 'package:reptrack/features/workout/domain/session_editing.dart';
import 'package:reptrack/features/workout/domain/workout_session.dart';

import '../../../support/app_harness.dart';
import '../../../support/fake_devices.dart';
import '../../../support/fakes.dart';
import '../../../support/test_database.dart';
import '../../../support/workout_fixtures.dart';

/// Odstęp większy niż blokada podwójnego tapnięcia po zatwierdzeniu serii.
const _afterCooldown = Duration(milliseconds: 400);

/// Uruchamia aplikację na telefonie 360 × 800 dp z ćwiczeniami z fixture
/// i szablonem „Push A”.
Future<AppDatabase> _launch(
  WidgetTester tester, {
  FakeRestNotifications? notifications,
  FakeScreenAwake? awake,
  Future<void> Function(AppDatabase db)? seed,
}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final db = widgetTestDatabase();
  await tester.runAsync(() async {
    final exercises = DriftExerciseRepository(db, testClock());
    for (final e in catalog.values) {
      await exercises.save(e);
    }
    await DriftTemplateRepository(db, testClock()).save(pushTemplate());
    await seed?.call(db);
  });
  return pumpRepTrack(
    tester,
    db: db,
    clock: testClock(),
    notifications: notifications,
    awake: awake,
  );
}

Future<WorkoutSession?> _active(WidgetTester tester, AppDatabase db) => tester
    .runAsync(() => DriftWorkoutRepository(db, testClock()).findActive())
    .then((s) => s);

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// Start „Push A” z listy szablonów (2 tapnięcia od ekranu Start).
Future<void> _startPushA(WidgetTester tester) async {
  await _tap(tester, navTab('Szablony'));
  await _tap(tester, find.byTooltip('Rozpocznij trening'));
}

List<SessionSet> _benchSets(WorkoutSession session) =>
    sortedSets(sortedExercises(session).first);

void main() {
  testWidgets('start → pierwsza seria w 3 tapnięciach, podpowiedź to 1 tap', (
    tester,
  ) async {
    final notifications = FakeRestNotifications();
    final awake = FakeScreenAwake();
    final db = await _launch(
      tester,
      notifications: notifications,
      awake: awake,
    );
    var taps = 0;
    Future<void> tap(Finder finder) async {
      await _tap(tester, finder);
      taps++;
    }

    await tap(navTab('Szablony'));
    await tap(find.byTooltip('Rozpocznij trening'));

    expect(find.text('Wyciskanie'), findsOneWidget);
    expect(awake.enabled, isTrue);
    expect(notifications.permissionRequests, 1);
    // Podpowiedzi są widoczne, ale żadna seria nie jest zatwierdzona.
    var session = await _active(tester, db);
    expect(
      session!.exercises.expand((e) => e.sets).where((s) => s.isCompleted),
      isEmpty,
    );

    await tap(find.text('Zatwierdź serię 1'));

    expect(taps, 3);
    session = await _active(tester, db);
    final warmup = _benchSets(session!).first;
    expect(warmup.isCompleted, isTrue);
    expect((warmup.weightG, warmup.reps), (40000, 10));
    final restEnd = testClock().nowUtc().add(const Duration(seconds: 150));
    expect(session.restEndsAt, restEnd);
    expect(notifications.endsAt, restEnd);
    expect(notifications.nextName, 'Wyciskanie');
    expect(find.text('Zatwierdź serię 2'), findsOneWidget);
    expect(find.text('Przerwa 2:30'), findsOneWidget);

    await tester.pump(_afterCooldown);
    await closeRepTrack(tester, db);
  });

  testWidgets('podpowiedź nigdy nie zatwierdza serii sama', (tester) async {
    final db = await _launch(tester);
    await _startPushA(tester);

    // Wpisany ciężar i upływ czasu nie zatwierdzają serii.
    await _tap(tester, find.byTooltip('Zwiększ: Ciężar'));
    await tester.pump(const Duration(seconds: 5));

    final session = await _active(tester, db);
    final warmup = _benchSets(session!).first;
    expect(warmup.weightG, 42500);
    expect(warmup.isCompleted, isFalse);
    expect(
      session.exercises.expand((e) => e.sets).where((s) => s.isCompleted),
      isEmpty,
    );

    await closeRepTrack(tester, db);
  });

  testWidgets('ciężar o krok: 2 tapnięcia, inne powtórzenia: 3 tapnięcia', (
    tester,
  ) async {
    final db = await _launch(tester);
    await _startPushA(tester);
    await _tap(tester, find.text('Zatwierdź serię 1'));
    await tester.pump(_afterCooldown);

    // Seria 2: plan 80 kg × 8; ciężar o krok w górę.
    await _tap(tester, find.byTooltip('Zwiększ: Ciężar'));
    await _tap(tester, find.text('Zatwierdź serię 2'));
    await tester.pump(_afterCooldown);

    // Seria 3: inne powtórzenia z siatki.
    await _tap(tester, find.byKey(const ValueKey('workout-value-reps')));
    await _tap(tester, find.text('6'));
    await _tap(tester, find.text('Zatwierdź serię 3'));
    await tester.pump(_afterCooldown);

    final sets = _benchSets((await _active(tester, db))!);
    expect(
      (sets[1].weightG, sets[1].reps, sets[1].isCompleted),
      (82500, 8, true),
    );
    expect(
      (sets[2].weightG, sets[2].reps, sets[2].isCompleted),
      (80000, 6, true),
    );

    await closeRepTrack(tester, db);
  });

  testWidgets('podpowiedź z poprzedniego wykonania ćwiczenia', (tester) async {
    final db = await _launch(
      tester,
      seed: (db) async {
        var past = buildSessionFromTemplate(
          template: pushTemplate(),
          exercises: catalog,
          ids: SequentialIds('past'),
          startedAt: DateTime.utc(2026, 10, 12, 16),
          timeZone: 'Europe/Warsaw',
        );
        final bench = sortedExercises(past).first;
        past = updateSet(
          past,
          bench.id,
          sortedSets(bench)[1].id,
          (s) => s.copyWith(
            weightG: 85000,
            reps: 10,
            completedAt: DateTime.utc(2026, 10, 12, 16, 10),
          ),
        );
        await DriftWorkoutRepository(db, testClock()).save(
          past.copyWith(
            status: SessionStatus.completed,
            endedAt: DateTime.utc(2026, 10, 12, 17),
          ),
        );
      },
    );
    await _startPushA(tester);

    // Kolumna „Poprz.” i podpowiedź w kolumnie wartości.
    expect(find.text('85×10'), findsNWidgets(2));
    await _tap(tester, find.text('Zatwierdź serię 1'));
    await tester.pump(_afterCooldown);
    await _tap(tester, find.text('Zatwierdź serię 2'));
    await tester.pump(_afterCooldown);

    final sets = _benchSets((await _active(tester, db))!);
    expect((sets[1].weightG, sets[1].reps), (85000, 10));

    await closeRepTrack(tester, db);
  });

  testWidgets('przerwa: ±15 s i pominięcie', (tester) async {
    final notifications = FakeRestNotifications();
    final db = await _launch(tester, notifications: notifications);
    await _startPushA(tester);
    await _tap(tester, find.text('Zatwierdź serię 1'));
    await tester.pump(_afterCooldown);
    final start = testClock().nowUtc();

    await _tap(tester, find.text('+15'));
    expect(find.text('Przerwa 2:45'), findsOneWidget);
    expect(
      (await _active(tester, db))!.restEndsAt,
      start.add(const Duration(seconds: 165)),
    );
    expect(notifications.endsAt, start.add(const Duration(seconds: 165)));

    await _tap(tester, find.text('−15'));
    await _tap(tester, find.text('−15'));
    expect(find.text('Przerwa 2:15'), findsOneWidget);

    await _tap(tester, find.text('Pomiń'));
    expect(find.textContaining('Przerwa'), findsNothing);
    expect((await _active(tester, db))!.restEndsAt, isNull);
    expect(notifications.endsAt, isNull);

    await closeRepTrack(tester, db);
  });

  testWidgets(
    'zakończenie: podsumowanie, samopoczucie, aktualizacja szablonu',
    (tester) async {
      final db = await _launch(tester);
      await _startPushA(tester);
      final sessionId = (await _active(tester, db))!.id;
      await _tap(tester, find.text('Zatwierdź serię 1'));
      await tester.pump(_afterCooldown);
      await _tap(tester, find.text('Zatwierdź serię 2'));
      await tester.pump(_afterCooldown);
      await _tap(tester, find.text('Dodaj serię'));

      await _tap(tester, find.byTooltip('Opcje treningu'));
      await _tap(tester, find.text('Zakończ trening'));
      await _tap(tester, find.text('Zakończ mimo to'));

      expect(find.text('Podsumowanie'), findsOneWidget);
      expect(find.text('640 kg'), findsOneWidget);
      expect(find.text('Zaktualizuj szablon „Push A”'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('• Wyciskanie: serie 4 → 5'),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.enterText(find.byType(TextField), 'Dobra forma');
      await _tap(tester, find.byTooltip('Samopoczucie 4 z 5'));
      await _tap(tester, find.text('Zaktualizuj szablon „Push A”'));
      await _tap(tester, find.text('Zakończ i zapisz'));

      expect(find.text('Trening zapisany'), findsOneWidget);
      expect(find.text('Pusty trening'), findsOneWidget);
      final saved = (await tester.runAsync(
        () => DriftWorkoutRepository(db, testClock()).findById(sessionId),
      ))!;
      expect(saved.status, SessionStatus.completed);
      expect(saved.endedAt, testClock().nowUtc());
      expect((saved.notes, saved.wellbeing), ('Dobra forma', 4));
      final template = (await tester.runAsync(
        () => DriftTemplateRepository(db, testClock()).findById('tpl'),
      ))!;
      expect(template.exercises.first.setCount, 5);
      expect(await _active(tester, db), isNull);

      await closeRepTrack(tester, db);
    },
  );

  testWidgets('porzucenie wymaga potwierdzenia i nie trafia do historii', (
    tester,
  ) async {
    final db = await _launch(tester);
    await _startPushA(tester);
    final sessionId = (await _active(tester, db))!.id;

    await _tap(tester, find.byTooltip('Opcje treningu'));
    await _tap(tester, find.text('Porzuć trening'));
    expect(find.text('Porzucić trening?'), findsOneWidget);
    await _tap(tester, find.text('Anuluj'));
    expect(await _active(tester, db), isNotNull);

    await _tap(tester, find.byTooltip('Opcje treningu'));
    await _tap(tester, find.text('Porzuć trening'));
    await _tap(tester, find.text('Porzuć'));

    expect(find.text('Trening porzucony'), findsOneWidget);
    expect(await _active(tester, db), isNull);
    expect(
      await tester.runAsync(
        () => DriftWorkoutRepository(db, testClock()).findById(sessionId),
      ),
      isNull,
    );

    await closeRepTrack(tester, db);
  });

  testWidgets('wznowienie po ponownym uruchomieniu aplikacji', (tester) async {
    final awake = FakeScreenAwake();
    final db = await _launch(tester, awake: awake);
    await _startPushA(tester);
    await _tap(tester, find.text('Zatwierdź serię 1'));
    await tester.pump(_afterCooldown);

    // Minimalizacja: pasek trwającego treningu, ekran może gasnąć.
    await _tap(tester, find.byTooltip('Zminimalizuj trening'));
    expect(awake.enabled, isFalse);
    expect(find.text('Trening trwa · 0:00'), findsOneWidget);

    // Restart: nowe drzewo widżetów na tej samej bazie.
    await tester.pumpWidget(const SizedBox.shrink());
    await pumpRepTrack(tester, db: db, clock: testClock());

    expect(find.text('Masz niedokończony trening'), findsOneWidget);
    expect(find.text('Trening trwa · 0:00'), findsOneWidget);
    await _tap(tester, find.text('Wznów'));
    expect(find.text('Zatwierdź serię 2'), findsOneWidget);
    expect(find.text('Przerwa 2:30'), findsOneWidget);

    await closeRepTrack(tester, db);
  });

  testWidgets('pusty trening: dodanie ćwiczenia i uzupełnienie wartości', (
    tester,
  ) async {
    final db = await _launch(tester);
    await _tap(tester, find.text('Pusty trening'));
    expect(find.text('Dodaj pierwsze ćwiczenie'), findsOneWidget);

    await _tap(tester, find.text('Dodaj ćwiczenia'));
    await _tap(tester, find.text('Deska'));
    await _tap(tester, find.text('Dodaj (1)'));
    expect(find.text('Deska'), findsOneWidget);

    // Brak podpowiedzi: zatwierdzenie otwiera wpis brakującego czasu.
    await _tap(tester, find.text('Zatwierdź serię 1'));
    expect(find.text('Uzupełnij: Czas'), findsOneWidget);
    expect(_activeSets(await _active(tester, db)), everyElement(isFalse));
    await tester.enterText(find.byType(TextField), '45');
    await _tap(tester, find.text('Gotowe'));
    expect(_activeSets(await _active(tester, db)), everyElement(isFalse));

    await _tap(tester, find.byTooltip('Zwiększ: Czas'));
    await _tap(tester, find.text('Zatwierdź serię 1'));
    await tester.pump(_afterCooldown);

    final set = sortedSets(sortedExercises((await _active(tester, db))!).first)
        .first;
    expect((set.durationS, set.isCompleted), (50, true));

    await closeRepTrack(tester, db);
  });

  testWidgets('drugi trening nie startuje, gdy trwa pierwszy', (tester) async {
    final db = await _launch(tester);
    await _startPushA(tester);
    await _tap(tester, find.byTooltip('Zminimalizuj trening'));

    await _tap(tester, find.byTooltip('Rozpocznij trening'));
    expect(find.text('Trwa inny trening'), findsOneWidget);
    await _tap(tester, find.text('Przejdź do treningu'));
    expect(find.text('Wyciskanie'), findsOneWidget);

    await closeRepTrack(tester, db);
  });

  testWidgets('prośba o dokładne alarmy pojawia się tylko raz', (tester) async {
    final notifications = FakeRestNotifications()..exactAllowed = false;
    final db = await _launch(tester, notifications: notifications);
    await _startPushA(tester);

    expect(find.text('Koniec przerwy na czas'), findsOneWidget);
    await _tap(tester, find.text('Zezwól'));
    expect(notifications.exactRequests, 1);

    await _tap(tester, find.byTooltip('Zminimalizuj trening'));
    await _tap(tester, find.text('Wróć'));
    expect(find.text('Koniec przerwy na czas'), findsNothing);
    expect(find.text('Zatwierdź serię 1'), findsOneWidget);

    await closeRepTrack(tester, db);
  });

  testWidgets('nieaktualny pusty strumień nie zamyka nowego treningu', (
    tester,
  ) async {
    // Na telefonie baza działa w osobnym wątku: tuż po starcie treningu
    // strumień aktywnej sesji może jeszcze podawać „brak treningu”.
    final db = widgetTestDatabase();
    final session = buildSessionFromTemplate(
      template: pushTemplate(),
      exercises: catalog,
      ids: SequentialIds('s'),
      startedAt: testClock().nowUtc(),
      timeZone: 'Europe/Warsaw',
    );
    await tester.runAsync(() async {
      for (final e in catalog.values) {
        await DriftExerciseRepository(db, testClock()).save(e);
      }
      await DriftTemplateRepository(db, testClock()).save(pushTemplate());
      await DriftWorkoutRepository(db, testClock()).save(session);
    });
    final stream = StreamController<WorkoutSession?>();
    addTearDown(stream.close);
    stream.add(null);
    await pumpRepTrack(
      tester,
      db: db,
      clock: testClock(),
      overrides: [activeSessionProvider.overrideWith((ref) => stream.stream)],
    );

    unawaited(
      GoRouter.of(tester.element(find.byType(Scaffold).first))
          .push(AppRoutes.workout),
    );
    // Ekran czeka na sesję (wskaźnik ładowania), więc bez pumpAndSettle.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    // Strumień dogania bazę dopiero po otwarciu ekranu treningu.
    stream.add(session);
    await tester.pumpAndSettle();

    expect(find.text('Zatwierdź serię 1'), findsOneWidget);

    await closeRepTrack(tester, db);
  });

  testWidgets('kończenie z niezatwierdzonymi seriami pyta', (tester) async {
    final db = await _launch(tester);
    await _startPushA(tester);
    await _tap(tester, find.text('Zatwierdź serię 1'));
    await tester.pump(_afterCooldown);

    await _tap(tester, find.byTooltip('Opcje treningu'));
    await _tap(tester, find.text('Zakończ trening'));
    expect(find.text('6 niezatwierdzonych serii'), findsOneWidget);
    await _tap(tester, find.text('Wróć do treningu'));
    expect(find.text('Podsumowanie'), findsNothing);
    expect(find.text('Zatwierdź serię 2'), findsOneWidget);

    await _tap(tester, find.byTooltip('Opcje treningu'));
    await _tap(tester, find.text('Zakończ trening'));
    await _tap(tester, find.text('Zakończ mimo to'));
    expect(find.text('Podsumowanie'), findsOneWidget);

    await closeRepTrack(tester, db);
  });
}

Iterable<bool> _activeSets(WorkoutSession? session) =>
    session!.exercises.expand((e) => e.sets).map((s) => s.isCompleted);
