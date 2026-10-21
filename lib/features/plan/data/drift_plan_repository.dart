import 'package:collection/collection.dart';
import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/upsert.dart';
import '../../../core/database/watch_tables.dart';
import '../../../core/domain/clock.dart';
import '../../../core/domain/local_date.dart';
import '../domain/plan.dart';
import '../domain/plan_repository.dart';

final class DriftPlanRepository implements PlanRepository {
  DriftPlanRepository(this._db, this._clock);

  final AppDatabase _db;
  final Clock _clock;

  @override
  Stream<PlanState> watch() => watchTables(_db, 'plan', {
    _db.weeklyPlans,
    _db.weeklyPlanDays,
    _db.plannedDays,
  }).asyncMap((_) => load());

  @override
  Future<PlanState> load() async {
    final planRows =
        await (_db.select(_db.weeklyPlans)
              ..where((t) => t.deletedAt.isNull())
              ..orderBy([(t) => OrderingTerm.asc(t.startsOn)]))
            .get();
    final dayRows =
        await (_db.select(_db.weeklyPlanDays)
              ..where((t) => t.deletedAt.isNull())
              ..orderBy([
                (t) => OrderingTerm.asc(t.weekday),
                (t) => OrderingTerm.asc(t.position),
              ]))
            .get();
    final datedRows =
        await (_db.select(_db.plannedDays)
              ..where((t) => t.deletedAt.isNull())
              ..orderBy([
                (t) => OrderingTerm.asc(t.date),
                (t) => OrderingTerm.asc(t.position),
              ]))
            .get();
    final daysByPlan = dayRows.groupListsBy((r) => r.planId);
    return (
      weekly: [
        for (final row in planRows)
          WeeklyPlan(
            id: row.id,
            startsOn: row.startsOn,
            endsOn: row.endsOn,
            days: [
              for (final d in daysByPlan[row.id] ?? const <WeeklyPlanDayRow>[])
                WeeklyPlanDay(
                  id: d.id,
                  weekday: d.weekday,
                  templateId: d.templateId,
                  position: d.position,
                ),
            ],
          ),
      ],
      days: [
        for (final row in datedRows)
          PlannedDay(
            id: row.id,
            date: row.date,
            kind: row.kind,
            templateId: row.templateId,
            position: row.position,
            note: row.note,
          ),
      ],
    );
  }

  @override
  Future<void> saveWeekly({
    required List<WeeklyPlan> save,
    List<String> delete = const [],
  }) => _db.transaction(() async {
    final now = _clock.nowUtc();
    for (final plan in save) {
      final existing = await (_db.select(
        _db.weeklyPlans,
      )..where((t) => t.id.equals(plan.id))).getSingleOrNull();
      await upsertIfChanged(
        _db,
        _db.weeklyPlans,
        existing: existing,
        candidate: WeeklyPlanRow(
          id: plan.id,
          createdAt: existing?.createdAt ?? now,
          updatedAt: existing?.updatedAt ?? now,
          deletedAt: existing?.deletedAt,
          startsOn: plan.startsOn,
          endsOn: plan.endsOn,
        ),
        touch: (row) => row.copyWith(updatedAt: now),
      );
      final existingDays = {
        for (final row in await (_db.select(
          _db.weeklyPlanDays,
        )..where((t) => t.planId.equals(plan.id) & t.deletedAt.isNull())).get())
          row.id: row,
      };
      for (final day in plan.days) {
        final previous = existingDays.remove(day.id);
        await upsertIfChanged(
          _db,
          _db.weeklyPlanDays,
          existing: previous,
          candidate: WeeklyPlanDayRow(
            id: day.id,
            createdAt: previous?.createdAt ?? now,
            updatedAt: previous?.updatedAt ?? now,
            planId: plan.id,
            weekday: day.weekday,
            templateId: day.templateId,
            position: day.position,
          ),
          touch: (row) => row.copyWith(updatedAt: now),
        );
      }
      for (final removed in existingDays.values) {
        await softDeleteWhere(
          _db,
          _db.weeklyPlanDays,
          column: 'id',
          value: removed.id,
          now: now,
        );
      }
    }
    for (final id in delete) {
      await softDeleteWhere(
        _db,
        _db.weeklyPlanDays,
        column: 'plan_id',
        value: id,
        now: now,
      );
      await softDeleteWhere(
        _db,
        _db.weeklyPlans,
        column: 'id',
        value: id,
        now: now,
      );
    }
  });

  @override
  Future<void> setDay(LocalDate date, List<PlannedDay> entries) =>
      setDays({date: entries});

  @override
  Future<void> setDays(Map<LocalDate, List<PlannedDay>> changes) =>
      _db.transaction(() async {
        final now = _clock.nowUtc();
        for (final MapEntry(key: date, value: entries) in changes.entries) {
          await _writeDay(date, entries, now);
        }
      });

  Future<void> _writeDay(
    LocalDate date,
    List<PlannedDay> entries,
    DateTime now,
  ) async {
    final existing = {
      for (final row in await (_db.select(
        _db.plannedDays,
      )..where((t) => t.date.equalsValue(date) & t.deletedAt.isNull())).get())
        row.id: row,
    };
    for (final entry in entries) {
      assert(entry.date == date, 'Wpis z innej daty');
      final previous = existing.remove(entry.id);
      await upsertIfChanged(
        _db,
        _db.plannedDays,
        existing: previous,
        candidate: PlannedDayRow(
          id: entry.id,
          createdAt: previous?.createdAt ?? now,
          updatedAt: previous?.updatedAt ?? now,
          date: date,
          kind: entry.kind,
          templateId: entry.templateId,
          position: entry.position,
          note: entry.note,
        ),
        touch: (row) => row.copyWith(updatedAt: now),
      );
    }
    for (final removed in existing.values) {
      await softDeleteWhere(
        _db,
        _db.plannedDays,
        column: 'id',
        value: removed.id,
        now: now,
      );
    }
  }
}
