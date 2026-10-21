import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:reptrack/core/domain/local_date.dart';
import 'package:reptrack/core/platform/plan_reminders.dart';
import 'package:reptrack/features/plan/data/plan_reminder_sync.dart';
import 'package:reptrack/features/plan/domain/plan.dart';

import '../../../support/workout_fixtures.dart';

// Poniedziałek 19.10.2026; plan: pon „Push A” (tpl), śr „Pull B” (tpl2).
const PlanState _plan = (
  weekly: [
    WeeklyPlan(
      id: 'wp',
      startsOn: LocalDate(2026, 10, 5),
      days: [
        WeeklyPlanDay(id: 'd1', weekday: 1, templateId: 'tpl', position: 0),
        WeeklyPlanDay(id: 'd3', weekday: 3, templateId: 'tpl2', position: 0),
      ],
    ),
  ],
  days: [],
);

final _templates = [
  pushTemplate(),
  pushTemplate().copyWith(id: 'tpl2', name: 'Pull B', exercises: []),
];

void main() {
  test('przypomnienia o 17:00 w dni z planem na dwa tygodnie', () {
    final reminders = planReminderList(
      plan: _plan,
      history: const [],
      templates: _templates,
      now: DateTime(2026, 10, 19, 16),
      minutes: 17 * 60,
    );

    expect(
      [for (final r in reminders) r.at.toLocal()],
      [
        DateTime(2026, 10, 19, 17),
        DateTime(2026, 10, 21, 17),
        DateTime(2026, 10, 26, 17),
        DateTime(2026, 10, 28, 17),
      ],
    );
    expect(reminders.first.workouts, ['Push A']);
    expect(reminders[1].workouts, ['Pull B']);
  });

  test(
    'bez dzisiejszego po godzinie przypomnienia i po zrobionym treningu',
    () {
      final late = planReminderList(
        plan: _plan,
        history: const [],
        templates: _templates,
        now: DateTime(2026, 10, 19, 18),
        minutes: 17 * 60,
      );
      expect(late.first.at.toLocal(), DateTime(2026, 10, 21, 17));

      final done = planReminderList(
        plan: _plan,
        history: [
          finishedPush('t', DateTime.utc(2026, 10, 19, 13), [(80000, 8)]),
        ],
        templates: _templates,
        now: DateTime(2026, 10, 19, 16),
        minutes: 17 * 60,
      );
      expect(done.first.at.toLocal(), DateTime(2026, 10, 21, 17));
    },
  );

  test('zarchiwizowany szablon nie przypomina', () {
    final reminders = planReminderList(
      plan: _plan,
      history: const [],
      templates: [
        _templates.first,
        _templates.last.copyWith(archivedAt: DateTime.utc(2026, 10, 1)),
      ],
      now: DateTime(2026, 10, 19, 16),
      minutes: 17 * 60,
    );

    expect(reminders.every((r) => r.workouts.single == 'Push A'), isTrue);
  });

  group('kolejka planowania', () {
    test(
      'naraz jedno planowanie, a na końcu obowiązuje najnowsza lista',
      () async {
        final reminders = _SlowReminders();
        final scheduler = PlanReminderScheduler(reminders);
        final first = [
          (at: DateTime.utc(2026, 10, 19, 15), workouts: ['A']),
        ];
        final second = [
          (at: DateTime.utc(2026, 10, 20, 15), workouts: ['B']),
        ];
        final third = <PlanReminder>[];

        final done = scheduler.request(first);
        unawaited(scheduler.request(second));
        unawaited(scheduler.request(third));
        expect(reminders.calls, [first]);

        reminders.finish();
        await pumpEventQueue();
        // Lista pośrednia jest pominięta: liczy się tylko najnowsza.
        expect(reminders.calls, [first, third]);
        reminders.finish();
        await done;

        expect(reminders.maxRunning, 1);
        expect(reminders.calls.last, third);
      },
    );

    test('błąd planowania nie blokuje kolejnych próśb', () async {
      final errors = <Object>[];
      final reminders = _SlowReminders()..failNext = true;
      final scheduler = PlanReminderScheduler(
        reminders,
        onError: (error, _) => errors.add(error),
      );

      final done = scheduler.request(const []);
      reminders.finish();
      await done;
      final again = scheduler.request(const []);
      reminders.finish();
      await again;

      expect(errors, hasLength(1));
      expect(reminders.calls, hasLength(2));
    });
  });
}

/// Planowanie, które kończy się dopiero po [finish].
final class _SlowReminders implements PlanReminders {
  final calls = <List<PlanReminder>>[];
  final _waiting = <Completer<void>>[];
  int _running = 0;
  int maxRunning = 0;
  bool failNext = false;

  void finish() => _waiting.removeAt(0).complete();

  @override
  Future<void> schedule(List<PlanReminder> reminders) async {
    calls.add(reminders);
    _running++;
    if (_running > maxRunning) maxRunning = _running;
    final wait = Completer<void>();
    _waiting.add(wait);
    await wait.future;
    _running--;
    if (failNext) {
      failNext = false;
      throw StateError('awaria systemu powiadomień');
    }
  }

  @override
  Future<bool> requestPermission() async => true;
}
