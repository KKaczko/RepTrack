import 'dart:math';

import 'package:collection/collection.dart';

import '../../../core/domain/ids.dart';
import '../../../core/domain/local_date.dart';
import '../../templates/domain/set_plan.dart';
import '../../templates/domain/template.dart';
import '../../workout/domain/workout_session.dart';
import 'plan.dart';

/// Plan na dni, realizacja i operacje na planie (ADR 0015). Czyste funkcje:
/// repozytorium zapisuje tylko to, co one zwrócą.

/// Trening zaplanowany na dzień.
typedef PlanItem = ({String templateId, String? note});

/// Plan jednego dnia.
final class DayPlan {
  const DayPlan({
    required this.date,
    required this.items,
    required this.fromDate,
  });

  final LocalDate date;
  final List<PlanItem> items;

  /// Dzień ma własne wpisy, które zastępują plan tygodniowy.
  final bool fromDate;

  bool get isRest => items.isEmpty;
}

/// Wersja planu tygodniowego obowiązująca w [date] (przy nakładaniu
/// najpóźniej rozpoczęta).
WeeklyPlan? weeklyPlanAt(List<WeeklyPlan> plans, LocalDate date) => plans
    .where((p) => p.covers(date))
    .sorted((a, b) => b.startsOn.compareTo(a.startsOn))
    .firstOrNull;

/// Plan dnia: wpisy na datę, a bez nich plan tygodniowy z tego dnia.
DayPlan dayPlan(PlanState plan, LocalDate date) {
  final entries = plan.days
      .where((d) => d.date == date)
      .sortedBy<num>((d) => d.position);
  if (entries.isNotEmpty) {
    return DayPlan(
      date: date,
      fromDate: true,
      items: [
        for (final e in entries)
          if (e.kind == PlannedKind.workout && e.templateId != null)
            (templateId: e.templateId!, note: e.note),
      ],
    );
  }
  final weekly = weeklyPlanAt(plan.weekly, date);
  return DayPlan(
    date: date,
    fromDate: false,
    items: [
      for (final d
          in (weekly?.days ?? const <WeeklyPlanDay>[])
              .where((d) => d.weekday == date.weekday)
              .sortedBy<num>((d) => d.position))
        (templateId: d.templateId, note: null),
    ],
  );
}

/// Stan zaplanowanego treningu.
enum PlanStatus {
  /// Zrobiony trening z tego szablonu.
  done,

  /// Tego dnia był inny trening.
  replaced,

  /// Dzień minął bez treningu.
  missed,

  /// Dziś, jeszcze nie zrobiony.
  today,

  /// Dzień w przyszłości.
  upcoming,
}

/// Trening z planu ze stanem i dopasowanym zakończonym treningiem.
typedef PlannedEntry = ({
  PlanItem item,
  PlanStatus status,
  WorkoutSession? session,
});

/// Dzień w kalendarzu: plan ze stanem i treningi spoza planu.
final class DayOverview {
  const DayOverview({
    required this.plan,
    required this.entries,
    required this.extra,
  });

  final DayPlan plan;
  final List<PlannedEntry> entries;

  /// Zakończone treningi, które nie pasują do planu.
  final List<WorkoutSession> extra;

  LocalDate get date => plan.date;
}

/// Zakończone treningi według daty lokalnej.
Map<LocalDate, List<WorkoutSession>> sessionsByDate(
  Iterable<WorkoutSession> completed,
) => completed.groupListsBy((s) => s.localDate);

/// Dopasowanie planu dnia do zakończonych treningów: najpierw ten sam
/// szablon, potem dowolny inny trening tego dnia (zastępstwo).
DayOverview dayOverview(
  PlanState plan,
  Map<LocalDate, List<WorkoutSession>> byDate,
  LocalDate date,
  LocalDate today,
) {
  final day = dayPlan(plan, date);
  final unused = [...?byDate[date]]..sortBy((s) => s.startedAt);
  final matched = List<WorkoutSession?>.filled(day.items.length, null);
  for (final (i, item) in day.items.indexed) {
    final session = unused.firstWhereOrNull(
      (s) => s.templateId == item.templateId,
    );
    if (session != null) {
      matched[i] = session;
      unused.remove(session);
    }
  }
  final entries = <PlannedEntry>[];
  for (final (i, item) in day.items.indexed) {
    if (matched[i] case final session?) {
      entries.add((item: item, status: PlanStatus.done, session: session));
    } else if (unused.isNotEmpty) {
      entries.add((
        item: item,
        status: PlanStatus.replaced,
        session: unused.removeAt(0),
      ));
    } else {
      final order = date.compareTo(today);
      entries.add((
        item: item,
        status: order < 0
            ? PlanStatus.missed
            : order == 0
            ? PlanStatus.today
            : PlanStatus.upcoming,
        session: null,
      ));
    }
  }
  return DayOverview(plan: day, entries: entries, extra: unused);
}

/// Realizacja planu w tygodniu: zrobione (także zastępstwa), wszystkie
/// zaplanowane i te, które jeszcze przed nami.
typedef Adherence = ({int done, int planned, int remaining});

Adherence weekAdherence(
  PlanState plan,
  Map<LocalDate, List<WorkoutSession>> byDate,
  LocalDate dayInWeek,
  LocalDate today,
) {
  final start = dayInWeek.startOfWeek;
  var done = 0;
  var planned = 0;
  var remaining = 0;
  for (var i = 0; i < 7; i++) {
    for (final entry in dayOverview(
      plan,
      byDate,
      start.addDays(i),
      today,
    ).entries) {
      planned++;
      switch (entry.status) {
        case PlanStatus.done || PlanStatus.replaced:
          done++;
        case PlanStatus.today || PlanStatus.upcoming:
          remaining++;
        case PlanStatus.missed:
          break;
      }
    }
  }
  return (done: done, planned: planned, remaining: remaining);
}

/// Liczba kolejnych tygodni z planem wykonanym w całości. Bieżący tydzień
/// dolicza się, gdy jest już pełny; niepełny nie przerywa serii.
int planStreak(
  PlanState plan,
  Map<LocalDate, List<WorkoutSession>> byDate,
  LocalDate today,
) {
  final earliest = [
    ...plan.weekly.map((p) => p.startsOn),
    ...plan.days.map((d) => d.date),
  ].minOrNull;
  if (earliest == null) return 0;
  final current = weekAdherence(plan, byDate, today, today);
  var streak = current.planned > 0 && current.done == current.planned ? 1 : 0;
  var week = today.startOfWeek.addDays(-7);
  while (week.addDays(6).compareTo(earliest) >= 0) {
    final adherence = weekAdherence(plan, byDate, week, today);
    if (adherence.planned == 0 || adherence.done < adherence.planned) break;
    streak++;
    week = week.addDays(-7);
  }
  return streak;
}

/// Pierwszy zaplanowany trening po dniu [after], najdalej [days] dni dalej.
({LocalDate date, PlanItem item})? nextPlanned(
  PlanState plan,
  LocalDate after, {
  int days = 14,
}) {
  for (var i = 1; i <= days; i++) {
    final date = after.addDays(i);
    if (dayPlan(plan, date).items.firstOrNull case final item?) {
      return (date: date, item: item);
    }
  }
  return null;
}

/// Dzień do przypomnienia: treningi z planu, których jeszcze nie zrobiono.
typedef ReminderDay = ({LocalDate date, List<String> templateIds});

/// Dni z zaplanowanymi, niezrobionymi treningami od [today] przez [days] dni.
List<ReminderDay> reminderDays(
  PlanState plan,
  Map<LocalDate, List<WorkoutSession>> byDate,
  LocalDate today, {
  int days = 14,
}) => [
  for (var i = 0; i < days; i++)
    if ([
          for (final entry in dayOverview(
            plan,
            byDate,
            today.addDays(i),
            today,
          ).entries)
            if (entry.status == PlanStatus.today ||
                entry.status == PlanStatus.upcoming)
              entry.item.templateId,
        ]
        case final ids when ids.isNotEmpty)
      (date: today.addDays(i), templateIds: ids),
];

// ------------------------------------------------------------ wpisy na daty

/// Wpisy dla daty z listy treningów; pusta lista to dzień wolny.
List<PlannedDay> _entries(
  LocalDate date,
  List<PlanItem> items,
  IdGenerator ids,
) => items.isEmpty
    ? [
        PlannedDay(
          id: ids.newId(),
          date: date,
          kind: PlannedKind.rest,
          position: 0,
        ),
      ]
    : [
        for (final (i, item) in items.indexed)
          PlannedDay(
            id: ids.newId(),
            date: date,
            kind: PlannedKind.workout,
            templateId: item.templateId,
            note: item.note,
            position: i,
          ),
      ];

/// Dodaje trening do dnia (plan tygodniowy tego dnia zostaje).
List<PlannedDay> scheduleOn(DayPlan day, String templateId, IdGenerator ids) =>
    _entries(day.date, [
      ...day.items,
      (templateId: templateId, note: null),
    ], ids);

/// Pomija trening; bez pozostałych dzień staje się wolny.
List<PlannedDay> skipItem(DayPlan day, int index, IdGenerator ids) =>
    _entries(day.date, [...day.items]..removeAt(index), ids);

/// Zamienia szablon treningu.
List<PlannedDay> replaceItem(
  DayPlan day,
  int index,
  String templateId,
  IdGenerator ids,
) => _entries(day.date, [
  for (final (i, item) in day.items.indexed)
    i == index ? (templateId: templateId, note: item.note) : item,
], ids);

/// Przenosi trening z dnia [from] na [to] (plan dnia docelowego zostaje).
({List<PlannedDay> from, List<PlannedDay> to}) moveItem(
  DayPlan from,
  int index,
  DayPlan to,
  IdGenerator ids,
) => (
  from: skipItem(from, index, ids),
  to: _entries(to.date, [...to.items, from.items[index]], ids),
);

// ------------------------------------------------------------ plan tygodnia

/// Wersja do edycji: obowiązująca dziś albo zaplanowana na później.
WeeklyPlan? currentWeeklyPlan(List<WeeklyPlan> plans, LocalDate today) =>
    weeklyPlanAt(plans, today) ??
    plans
        .where((p) => p.startsOn.compareTo(today) > 0)
        .sorted((a, b) => a.startsOn.compareTo(b.startsOn))
        .firstOrNull;

/// Szablony w dniach tygodnia (1–7), w kolejności.
Map<int, List<String>> weeklyTemplates(WeeklyPlan? plan) => {
  for (var weekday = 1; weekday <= 7; weekday++)
    weekday: [
      for (final d
          in (plan?.days ?? const <WeeklyPlanDay>[])
              .where((d) => d.weekday == weekday)
              .sortedBy<num>((d) => d.position))
        d.templateId,
    ],
};

/// Zmiany po edycji planu tygodniowego.
typedef WeeklyEdit = ({List<WeeklyPlan> save, List<String> delete});

/// Edycja planu tygodniowego od [today]. Plan, który już działał, zostaje
/// zamknięty na wczoraj, a zmiany idą do nowej wersji, więc przeszłe dni
/// i realizacja się nie zmieniają. Wersję, która jeszcze nie działała,
/// poprawiamy w miejscu. Pusty plan wyłącza planowanie od dziś.
WeeklyEdit editWeeklyPlan({
  required List<WeeklyPlan> plans,
  required Map<int, List<String>> days,
  required LocalDate today,
  required IdGenerator ids,
}) {
  const unchanged = (save: <WeeklyPlan>[], delete: <String>[]);
  final current = currentWeeklyPlan(plans, today);
  final empty = days.values.every((t) => t.isEmpty);
  final before = weeklyTemplates(current);
  final same = [
    for (var weekday = 1; weekday <= 7; weekday++)
      const ListEquality<String>().equals(
        before[weekday],
        days[weekday] ?? const [],
      ),
  ].every((e) => e);
  if (same && (current != null || empty)) return unchanged;

  List<WeeklyPlanDay> build(List<WeeklyPlanDay> previous) => [
    for (var weekday = 1; weekday <= 7; weekday++)
      for (final (position, templateId) in (days[weekday] ?? const []).indexed)
        WeeklyPlanDay(
          id:
              previous
                  .firstWhereOrNull(
                    (d) => d.weekday == weekday && d.position == position,
                  )
                  ?.id ??
              ids.newId(),
          weekday: weekday,
          templateId: templateId,
          position: position,
        ),
  ];

  if (current == null) {
    return (
      save: [WeeklyPlan(id: ids.newId(), startsOn: today, days: build([]))],
      delete: const [],
    );
  }
  if (current.startsOn.compareTo(today) >= 0) {
    return empty
        ? (save: const [], delete: [current.id])
        : (
            save: [current.copyWith(days: build(current.days))],
            delete: const [],
          );
  }
  return (
    save: [
      current.copyWith(endsOn: today.addDays(-1)),
      if (!empty) WeeklyPlan(id: ids.newId(), startsOn: today, days: build([])),
    ],
    delete: const [],
  );
}

// ------------------------------------------------------------ opis szablonu

/// Krótki opis szablonu do karty dnia.
typedef TemplatePreview = ({
  int exercises,
  int sets,
  int minutes,
  List<String> exerciseIds,
});

/// Szacowany czas jednej serii bez przerwy.
const _secondsPerSet = 40;

/// Liczba ćwiczeń i serii oraz szacowany czas (seria ok. 40 s plus
/// przerwa z planu albo domyślna), zaokrąglony do 5 minut.
TemplatePreview templatePreview(
  Template template, {
  required int defaultRestSeconds,
}) {
  final exercises = template.exercises.sortedBy<num>((e) => e.position);
  var sets = 0;
  var seconds = 0;
  for (final exercise in exercises) {
    for (final set in resolveEffectiveSets(exercise)) {
      sets++;
      seconds += _secondsPerSet + (set.restSeconds ?? defaultRestSeconds);
    }
  }
  return (
    exercises: exercises.length,
    sets: sets,
    minutes: sets == 0 ? 0 : max(5, (seconds / 300).round() * 5),
    exerciseIds: [for (final e in exercises) e.exerciseId],
  );
}
