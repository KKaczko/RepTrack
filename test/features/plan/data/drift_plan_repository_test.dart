import 'package:flutter_test/flutter_test.dart';
import 'package:reptrack/core/database/app_database.dart';
import 'package:reptrack/core/domain/local_date.dart';
import 'package:reptrack/features/exercises/data/drift_exercise_repository.dart';
import 'package:reptrack/features/plan/data/drift_plan_repository.dart';
import 'package:reptrack/features/plan/domain/plan.dart';
import 'package:reptrack/features/templates/data/drift_template_repository.dart';

import '../../../support/test_database.dart';
import '../../../support/workout_fixtures.dart';

const _monday = LocalDate(2026, 10, 12);

const _plan = WeeklyPlan(
  id: 'wp',
  startsOn: _monday,
  days: [
    WeeklyPlanDay(id: 'd1', weekday: 1, templateId: 'tpl', position: 0),
    WeeklyPlanDay(id: 'd2', weekday: 3, templateId: 'tpl', position: 0),
  ],
);

void main() {
  late AppDatabase db;
  late DriftPlanRepository repo;

  setUp(() async {
    db = memoryDatabase();
    repo = DriftPlanRepository(db, testClock());
    for (final e in catalog.values) {
      await DriftExerciseRepository(db, testClock()).save(e);
    }
    await DriftTemplateRepository(db, testClock()).save(pushTemplate());
  });
  tearDown(() => db.close());

  test('pusta baza: pusty plan', () async {
    final plan = await repo.load();
    expect(plan.weekly, isEmpty);
    expect(plan.days, isEmpty);
  });

  test('zapis i odczyt planu tygodniowego z dniami', () async {
    await repo.saveWeekly(save: const [_plan]);

    expect((await repo.load()).weekly, [_plan]);
  });

  test('usunięty dzień i usunięta wersja znikają (miękko)', () async {
    await repo.saveWeekly(save: const [_plan]);
    await repo.saveWeekly(
      save: [
        _plan.copyWith(days: [_plan.days.first]),
      ],
    );
    expect((await repo.load()).weekly.single.days, hasLength(1));

    await repo.saveWeekly(save: const [], delete: ['wp']);
    expect((await repo.load()).weekly, isEmpty);
    final rows = await db.select(db.weeklyPlanDays).get();
    expect(rows.every((r) => r.deletedAt != null), isTrue);
  });

  test('wpisy na datę: zastąpienie i przywrócenie planu', () async {
    await repo.setDay(_monday, const [
      PlannedDay(
        id: 'p1',
        date: _monday,
        kind: PlannedKind.workout,
        templateId: 'tpl',
        position: 0,
      ),
    ]);
    await repo.setDay(_monday, const [
      PlannedDay(id: 'p2', date: _monday, kind: PlannedKind.rest, position: 0),
    ]);
    expect((await repo.load()).days.single.id, 'p2');

    await repo.setDay(_monday, const []);
    expect((await repo.load()).days, isEmpty);
  });

  test('trening na datę wymaga szablonu (CHECK w bazie)', () async {
    await expectLater(
      repo.setDay(_monday, const [
        PlannedDay(
          id: 'bad',
          date: _monday,
          kind: PlannedKind.workout,
          position: 0,
        ),
      ]),
      throwsA(anything),
    );
  });

  test('strumień oddaje plan po każdej zmianie', () async {
    final states = repo.watch();
    final expectation = expectLater(
      states.map((s) => s.weekly.length),
      emitsThrough(1),
    );
    await repo.saveWeekly(save: const [_plan]);
    await expectation;
  });
}
