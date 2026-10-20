import 'package:flutter_test/flutter_test.dart';
import 'package:reptrack/core/domain/local_date.dart';
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
}
