import 'package:flutter_test/flutter_test.dart';
import 'package:reptrack/core/domain/local_date.dart';
import 'package:reptrack/features/plan/domain/plan.dart';
import 'package:reptrack/features/plan/domain/plan_schedule.dart';
import 'package:reptrack/features/workout/domain/workout_session.dart';

import '../../../support/fakes.dart';
import '../../../support/workout_fixtures.dart';

// Poniedziałki: 28.09, 5.10, 12.10 (2026). „Dziś” to środa 14.10.
const _today = LocalDate(2026, 10, 14);

WeeklyPlan _plan(
  String id,
  LocalDate startsOn,
  Map<int, List<String>> days, {
  LocalDate? endsOn,
}) => WeeklyPlan(
  id: id,
  startsOn: startsOn,
  endsOn: endsOn,
  days: [
    for (final MapEntry(key: weekday, value: templates) in days.entries)
      for (final (i, t) in templates.indexed)
        WeeklyPlanDay(
          id: '$id-$weekday-$i',
          weekday: weekday,
          templateId: t,
          position: i,
        ),
  ],
);

/// Zakończony trening z szablonu [templateId] w dniu [day] (18:00 w Warszawie).
WorkoutSession _done(String id, LocalDate day, String templateId) =>
    finishedPush(id, DateTime.utc(day.year, day.month, day.day, 16), [
      (80000, 8),
    ]).copyWith(templateId: templateId);

/// Plan: pon tpl, śr pull, pt legs od 28.09.
final _weekly = _plan('wp', const LocalDate(2026, 9, 28), {
  1: ['tpl'],
  3: ['pull'],
  5: ['legs'],
});

void main() {
  group('plan dnia', () {
    test('z planu tygodniowego według dnia tygodnia', () {
      final PlanState plan = (weekly: [_weekly], days: []);

      expect(
        dayPlan(plan, const LocalDate(2026, 10, 12)).items.single.templateId,
        'tpl',
      );
      expect(dayPlan(plan, const LocalDate(2026, 10, 13)).isRest, isTrue);
      // Przed początkiem planu nic nie jest zaplanowane.
      expect(dayPlan(plan, const LocalDate(2026, 9, 21)).isRest, isTrue);
    });

    test('wpis na datę zastępuje plan tygodniowy tego dnia', () {
      final PlanState plan = (
        weekly: [_weekly],
        days: const [
          PlannedDay(
            id: 'd1',
            date: LocalDate(2026, 10, 14),
            kind: PlannedKind.rest,
            position: 0,
          ),
        ],
      );

      final day = dayPlan(plan, const LocalDate(2026, 10, 14));
      expect(day.isRest, isTrue);
      expect(day.fromDate, isTrue);
    });

    test('wersje: przeszłe dni zachowują dawny plan', () {
      final PlanState plan = (
        weekly: [
          _plan('a', const LocalDate(2026, 9, 28), {
            1: ['tpl'],
          }, endsOn: const LocalDate(2026, 10, 11)),
          _plan('b', const LocalDate(2026, 10, 12), {
            2: ['tpl'],
          }),
        ],
        days: [],
      );

      expect(dayPlan(plan, const LocalDate(2026, 10, 5)).items, hasLength(1));
      expect(dayPlan(plan, const LocalDate(2026, 10, 12)).isRest, isTrue);
      expect(dayPlan(plan, const LocalDate(2026, 10, 13)).items, hasLength(1));
    });
  });

  group('realizacja', () {
    final PlanState plan = (weekly: [_weekly], days: []);

    test('stany: wykonany, zastąpiony, pominięty, dziś, zaplanowany', () {
      final byDate = sessionsByDate([
        _done('a', const LocalDate(2026, 10, 12), 'tpl'),
        _done('b', const LocalDate(2026, 10, 9), 'tpl'),
        _done('c', const LocalDate(2026, 10, 13), 'tpl'),
      ]);
      PlanStatus status(LocalDate d) =>
          dayOverview(plan, byDate, d, _today).entries.single.status;

      expect(status(const LocalDate(2026, 10, 12)), PlanStatus.done);
      // Piątek 9.10: plan „legs”, zrobiony inny trening.
      expect(status(const LocalDate(2026, 10, 9)), PlanStatus.replaced);
      expect(status(const LocalDate(2026, 10, 7)), PlanStatus.missed);
      expect(status(_today), PlanStatus.today);
      expect(status(const LocalDate(2026, 10, 16)), PlanStatus.upcoming);
      // Wtorek bez planu: trening „dodatkowy”.
      final tuesday = dayOverview(
        plan,
        byDate,
        const LocalDate(2026, 10, 13),
        _today,
      );
      expect(tuesday.entries, isEmpty);
      expect(tuesday.extra, hasLength(1));
    });

    test('tydzień: zrobione, zaplanowane, przed nami', () {
      final byDate = sessionsByDate([
        _done('a', const LocalDate(2026, 10, 12), 'tpl'),
      ]);

      expect(weekAdherence(plan, byDate, _today, _today), (
        done: 1,
        planned: 3,
        remaining: 2,
      ));
    });

    test('seria tygodni z planem wykonanym w całości', () {
      final PlanState mondays = (
        weekly: [
          _plan('m', const LocalDate(2026, 9, 28), {
            1: ['tpl'],
          }),
        ],
        days: [],
      );
      final all = [
        _done('a', const LocalDate(2026, 9, 28), 'tpl'),
        _done('b', const LocalDate(2026, 10, 5), 'tpl'),
        _done('c', const LocalDate(2026, 10, 12), 'tpl'),
      ];

      expect(planStreak(mondays, sessionsByDate(all), _today), 3);
      expect(
        planStreak(mondays, sessionsByDate([all.first, all.last]), _today),
        1,
      );
      expect(planStreak(emptyPlan, sessionsByDate(all), _today), 0);
    });
  });

  group('operacje na dniach', () {
    final PlanState plan = (weekly: [_weekly], days: []);
    final monday = dayPlan(plan, const LocalDate(2026, 10, 12));
    final tuesday = dayPlan(plan, const LocalDate(2026, 10, 13));

    test('dodanie treningu zostawia plan tygodniowy dnia', () {
      final entries = scheduleOn(monday, 'pull', SequentialIds('x'));
      expect([for (final e in entries) e.templateId], ['tpl', 'pull']);
      expect(entries.every((e) => e.date == monday.date), isTrue);
    });

    test('pominięcie jedynego treningu daje dzień wolny', () {
      final entries = skipItem(monday, 0, SequentialIds('x'));
      expect(entries.single.kind, PlannedKind.rest);
    });

    test('przeniesienie na jutro i zamiana szablonu', () {
      final moved = moveItem(monday, 0, tuesday, SequentialIds('x'));
      expect(moved.from.single.kind, PlannedKind.rest);
      expect(moved.to.single.templateId, 'tpl');
      expect(moved.to.single.date, tuesday.date);

      final replaced = replaceItem(monday, 0, 'legs', SequentialIds('x'));
      expect(replaced.single.templateId, 'legs');
    });
  });

  group('edycja planu tygodniowego', () {
    final days = {
      1: ['tpl'],
      4: ['pull'],
    };

    test('pierwszy plan zaczyna się dziś', () {
      final edit = editWeeklyPlan(
        plans: const [],
        days: days,
        today: _today,
        ids: SequentialIds('x'),
      );
      expect(edit.save.single.startsOn, _today);
      expect(edit.save.single.days, hasLength(2));
    });

    test('działający plan: zamknięty na wczoraj i nowa wersja od dziś', () {
      final edit = editWeeklyPlan(
        plans: [_weekly],
        days: days,
        today: _today,
        ids: SequentialIds('x'),
      );
      expect(edit.save.first.id, 'wp');
      expect(edit.save.first.endsOn, const LocalDate(2026, 10, 13));
      expect(edit.save.last.startsOn, _today);
      expect(edit.save.last.endsOn, isNull);
    });

    test('plan zaczęty dziś: poprawka w miejscu, te same id slotów', () {
      final fresh = _plan('f', _today, {
        1: ['tpl'],
      });
      final edit = editWeeklyPlan(
        plans: [fresh],
        days: days,
        today: _today,
        ids: SequentialIds('x'),
      );
      expect(edit.save.single.id, 'f');
      expect(edit.save.single.days.first.id, 'f-1-0');
    });

    test('bez zmian nic nie zapisuje; pusty plan wyłącza planowanie', () {
      final same = editWeeklyPlan(
        plans: [_weekly],
        days: weeklyTemplates(_weekly),
        today: _today,
        ids: SequentialIds('x'),
      );
      expect(same.save, isEmpty);

      final off = editWeeklyPlan(
        plans: [_weekly],
        days: const {},
        today: _today,
        ids: SequentialIds('x'),
      );
      expect(off.save.single.endsOn, const LocalDate(2026, 10, 13));

      final future = _plan('n', _today.addDays(3), {
        2: ['tpl'],
      });
      final removed = editWeeklyPlan(
        plans: [future],
        days: const {},
        today: _today,
        ids: SequentialIds('x'),
      );
      expect(removed.delete, ['n']);
    });
  });

  test('opis szablonu: ćwiczenia, serie i szacowany czas', () {
    // Ławka: 4 serie z przerwą 150 s; podciąganie: 3 serie z domyślną 120 s.
    // 4 × (40 + 150) + 3 × (40 + 120) = 1240 s ≈ 20 min.
    final preview = templatePreview(pushTemplate(), defaultRestSeconds: 120);

    expect(preview.exercises, 2);
    expect(preview.sets, 7);
    expect(preview.minutes, 20);
    expect(preview.exerciseIds, ['bench', 'pullup']);
  });
}
