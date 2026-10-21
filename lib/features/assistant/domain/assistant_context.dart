import 'package:collection/collection.dart';

import '../../../core/domain/local_date.dart';
import '../../../core/domain/training.dart';
import '../../../core/domain/units.dart';
import '../../../core/l10n/formatters.dart';
import '../../backup/domain/workout_export.dart';
import '../../exercises/domain/exercise.dart';
import '../../history/domain/history_queries.dart';
import '../../plan/domain/plan.dart';
import '../../plan/domain/plan_schedule.dart';
import '../../progress/domain/metrics.dart';
import '../../progress/domain/progress_period.dart';
import '../../templates/domain/set_plan.dart';
import '../../templates/domain/template.dart';
import '../../workout/domain/session_editing.dart';
import '../../workout/domain/session_summary.dart';
import '../../workout/domain/workout_session.dart';

/// Kontekst dla modelu językowego (ADR 0014): zwięzły Markdown z danymi
/// policzonymi przez aplikację, żeby model nie musiał (i nie mógł) zgadywać
/// liczb.

/// Teksty kontekstu w języku użytkownika (dostarcza warstwa prezentacji).
final class AssistantContextLabels {
  const AssistantContextLabels({
    required this.export,
    required this.title,
    required this.intro,
    required this.summary,
    required this.before,
    required this.workouts,
    required this.sets,
    required this.volume,
    required this.time,
    required this.duration,
    required this.muscles,
    required this.musclesNone,
    required this.muscle,
    required this.exercises,
    required this.e1rm,
    required this.maxReps,
    required this.maxDuration,
    required this.repsUnit,
    required this.change,
    required this.bestSet,
    required this.exerciseWorkouts,
    required this.last,
    required this.session,
    required this.compare,
    required this.previous,
    required this.now,
    required this.firstTime,
    required this.records,
    required this.noRecords,
    required this.repsAtLeast,
    required this.template,
    required this.plan,
    required this.rest,
    required this.history,
    required this.noHistory,
    required this.planSection,
    required this.planWeek,
    required this.planStreak,
    required this.planUpcoming,
    required this.planWeekly,
    required this.planRest,
    required this.planExtra,
    required this.planStatus,
    required this.weekday,
    required this.templates,
    required this.noWorkouts,
  });

  /// Nagłówek sekcji szablonów.
  final String templates;

  /// Informacja, że nie ma jeszcze zakończonych treningów.
  final String noWorkouts;

  /// Teksty tabel treningów (eksport Markdown).
  final ExportLabels export;
  final String Function(String date) title;
  final String Function(String unit) intro;
  final String Function(String from, String to) summary;
  final String Function(String value) before;
  final String workouts;
  final String sets;
  final String volume;
  final String time;
  final String Function(Duration duration) duration;
  final String muscles;
  final String Function(String list) musclesNone;
  final String Function(MuscleGroup muscle) muscle;
  final String exercises;
  final String e1rm;
  final String maxReps;
  final String maxDuration;
  final String repsUnit;
  final String change;
  final String bestSet;
  final String exerciseWorkouts;
  final String Function(String date) last;
  final String session;
  final String compare;
  final String Function(String date, String sets) previous;
  final String Function(String sets) now;
  final String firstTime;
  final String records;
  final String noRecords;
  final String Function(int reps) repsAtLeast;
  final String Function(String name) template;
  final String Function(String sets) plan;
  final String Function(String time) rest;
  final String history;
  final String noHistory;

  // Plan treningów (ADR 0015).
  final String planSection;
  final String Function(String from, int done, int planned) planWeek;
  final String Function(int weeks) planStreak;
  final String planUpcoming;
  final String planWeekly;
  final String planRest;
  final String planExtra;
  final String Function(PlanStatus status) planStatus;

  /// Nazwa dnia tygodnia (1 = poniedziałek).
  final String Function(int weekday) weekday;
}

/// Ustawienia formatowania kontekstu.
typedef AssistantFormat = ({
  AssistantContextLabels labels,
  WeightUnit unit,
  String locale,
});

/// Najwięcej ćwiczeń w przeglądzie i treningów w tabelach.
const assistantMaxExercises = 8;
const assistantRecentWorkouts = 3;
const assistantPerformancesPerExercise = 3;
const assistantMaxTemplates = 8;

/// Ile danych trafia do przeglądu; [noteChars] null = notatki w całości.
typedef AssistantLimits = ({
  int exercises,
  int recentWorkouts,
  int? noteChars,
  int templates,
});

/// Kolejne, coraz krótsze warianty przeglądu: najpierw skrócone notatki,
/// potem jeden ostatni trening zamiast trzech, na końcu połowa ćwiczeń
/// i szablonów.
const assistantLimitLevels = <AssistantLimits>[
  (
    exercises: assistantMaxExercises,
    recentWorkouts: assistantRecentWorkouts,
    noteChars: null,
    templates: assistantMaxTemplates,
  ),
  (
    exercises: assistantMaxExercises,
    recentWorkouts: assistantRecentWorkouts,
    noteChars: 200,
    templates: assistantMaxTemplates,
  ),
  (
    exercises: assistantMaxExercises,
    recentWorkouts: 1,
    noteChars: 200,
    templates: assistantMaxTemplates,
  ),
  (exercises: 4, recentWorkouts: 1, noteChars: 200, templates: 4),
];

/// Ogólny przegląd do rozmowy: podsumowanie 4 tygodni z porównaniem, serie
/// na partię, postęp ćwiczeń z 3 miesięcy, aktywne szablony, plan treningów
/// (gdy jest) i ostatnie treningi. [history] od najnowszego, jak
/// w historii. Bez zakończonych treningów zostają szablony i plan.
String coachContext({
  required List<WorkoutSession> history,
  required Map<String, Exercise> catalog,
  required LocalDate today,
  required AssistantFormat format,
  PlanState plan = emptyPlan,
  Map<String, String> templateNames = const {},
  List<Template> templates = const [],
  AssistantLimits limits = (
    exercises: assistantMaxExercises,
    recentWorkouts: assistantRecentWorkouts,
    noteChars: null,
    templates: assistantMaxTemplates,
  ),
}) {
  final (:labels, :unit, :locale) = format;
  final buffer = StringBuffer()
    ..writeln('# ${labels.title(today.toIso())}')
    ..writeln()
    ..writeln(labels.intro(weightUnitLabel(unit)));
  if (history.isEmpty) {
    buffer
      ..writeln()
      ..writeln(labels.noWorkouts);
  } else {
    _historyOverview(buffer, history, catalog, today, format, limits);
  }
  _templatesSection(buffer, templates, catalog, format, limits.templates);

  if (plan.weekly.isNotEmpty || plan.days.isNotEmpty) {
    buffer.write(
      planContext(
        plan: plan,
        history: history,
        templateNames: {
          for (final t in templates) t.id: t.name,
          ...templateNames,
        },
        today: today,
        labels: labels,
      ),
    );
  }

  // Ostatnie treningi w tabelach.
  final recent = [
    for (final session in history.take(limits.recentWorkouts))
      if (limits.noteChars case final max?)
        _shortNotes(session, max)
      else
        session,
  ].reversed;
  final rows = exportRows(recent.toList(), const ExportFilter());
  if (rows.isNotEmpty) {
    buffer
      ..writeln()
      ..write(
        _demote(
          exportMarkdown(
            rows,
            labels: labels.export,
            unit: unit,
            exerciseNames: _names(catalog),
          ),
        ),
      );
  }
  return buffer.toString();
}

/// Podsumowanie 4 tygodni, serie na partię i postęp ćwiczeń.
void _historyOverview(
  StringBuffer buffer,
  List<WorkoutSession> history,
  Map<String, Exercise> catalog,
  LocalDate today,
  AssistantFormat format,
  AssistantLimits limits,
) {
  final (:labels, :unit, :locale) = format;

  // Podsumowanie 4 tygodni.
  final range = periodRange(ProgressPeriod.weeks4, today);
  final now = summarizePeriod(history, range);
  final before = summarizePeriod(
    history,
    previousRange(ProgressPeriod.weeks4, today)!,
  );
  String line(String label, String value, String previous) =>
      '- $label: $value (${labels.before(previous)})';
  buffer
    ..writeln()
    ..writeln('## ${labels.summary(range.from!.toIso(), range.to.toIso())}')
    ..writeln()
    ..writeln(line(labels.workouts, '${now.workouts}', '${before.workouts}'))
    ..writeln(line(labels.sets, '${now.sets}', '${before.sets}'))
    ..writeln(
      line(
        labels.volume,
        formatVolume(now.volumeG, unit, locale),
        formatVolume(before.volumeG, unit, locale),
      ),
    )
    ..writeln(
      line(
        labels.time,
        labels.duration(now.duration),
        labels.duration(before.duration),
      ),
    );

  // Serie na partię.
  final muscles = weeklySetsPerMuscle(
    history,
    range,
    catalog,
    periodWeeks(ProgressPeriod.weeks4, history, today),
  );
  buffer
    ..writeln()
    ..writeln('## ${labels.muscles}')
    ..writeln();
  for (final row in muscles) {
    buffer.writeln(
      '- ${labels.muscle(row.muscle)}: '
      '${formatDecimal(row.sets, locale, maxDecimals: 1)}',
    );
  }
  final trained = {for (final row in muscles) row.muscle};
  final skipped = [
    for (final muscle in MuscleGroup.values)
      if (!trained.contains(muscle)) labels.muscle(muscle),
  ];
  if (skipped.isNotEmpty) {
    buffer.writeln(labels.musclesNone(skipped.join(', ')));
  }

  // Ćwiczenia z 3 miesięcy, od ostatnio wykonanego.
  final months = periodRange(ProgressPeriod.months3, today);
  final ids = <String>[];
  for (final session in history) {
    if (!inRange(session.localDate, months)) continue;
    for (final exercise in sortedExercises(session)) {
      if (_worked(exercise) && !ids.contains(exercise.exerciseId)) {
        ids.add(exercise.exerciseId);
      }
    }
  }
  if (ids.isNotEmpty) {
    buffer
      ..writeln()
      ..writeln('## ${labels.exercises}')
      ..writeln();
    for (final id in ids.take(limits.exercises)) {
      final performances = [
        for (final p in exercisePerformances(history, id))
          if (_worked(p.exercise)) p,
      ];
      final progress = exerciseProgress([
        for (final p in performances)
          (date: p.session.localDate, exercise: p.exercise),
      ], months);
      final name = _name(catalog, performances.first.exercise);
      final metric = progress.metric;
      final parts = <String>[
        if (metric != null && progress.best != null)
          '${_metricLabel(labels, metric)} '
              '${_metricValue(format, metric, progress.best!)}',
        if (progress.changePercent case final change?)
          '${labels.change} ${_percent(change, locale)}',
        if (metric != null && progress.bestSet != null)
          '${labels.bestSet} '
              '${_bestSet(format, metric, progress.bestSet!)}',
        '${labels.exerciseWorkouts}: ${progress.workouts}',
        labels.last(performances.first.session.localDate.toIso()),
      ];
      buffer.writeln('- $name: ${parts.join('; ')}');
    }
  }
}

/// Aktywne szablony z planem serii, np. „3 × Robocza: 8–12 powt., 80 kg”.
void _templatesSection(
  StringBuffer buffer,
  List<Template> templates,
  Map<String, Exercise> catalog,
  AssistantFormat format,
  int limit,
) {
  final active = [
    for (final t in templates)
      if (!t.isArchived) t,
  ];
  if (active.isEmpty) return;
  buffer
    ..writeln()
    ..writeln('## ${format.labels.templates}');
  for (final template in active.take(limit)) {
    buffer
      ..writeln()
      ..writeln('### ${template.name}');
    final exercises = [...template.exercises]
      ..sort((a, b) => a.position.compareTo(b.position));
    for (final planned in exercises) {
      final name = catalog[planned.exerciseId]?.name ?? planned.exerciseId;
      final groups = <({String text, int count})>[];
      for (final set in resolveEffectiveSets(planned)) {
        final text = _planSet(format, set);
        if (groups.lastOrNull case final last? when last.text == text) {
          groups.last = (text: text, count: last.count + 1);
        } else {
          groups.add((text: text, count: 1));
        }
      }
      buffer.writeln(
        '- $name: ${[for (final g in groups) '${g.count} × ${g.text}'].join('; ')}',
      );
    }
  }
}

/// Trening z notatkami skróconymi do [max] znaków.
WorkoutSession _shortNotes(WorkoutSession session, int max) {
  String? clip(String? text) => text == null || text.length <= max
      ? text
      : '${text.substring(0, max).trimRight()}…';
  return session.copyWith(
    notes: clip(session.notes),
    exercises: [
      for (final e in session.exercises) e.copyWith(note: clip(e.note)),
    ],
  );
}

/// Sekcja planu: realizacja i seria, bieżący tydzień ze stanami, najbliższe
/// 7 dni i obowiązujący plan tygodniowy.
String planContext({
  required PlanState plan,
  required List<WorkoutSession> history,
  required Map<String, String> templateNames,
  required LocalDate today,
  required AssistantContextLabels labels,
}) {
  final byDate = sessionsByDate(history);
  final week = weekAdherence(plan, byDate, today, today);
  final start = today.startOfWeek;
  String name(String id) => templateNames[id] ?? id;
  String day(LocalDate date) =>
      '${labels.weekday(date.weekday)} ${date.toIso()}';
  String describe(DayOverview overview) {
    final parts = [
      for (final entry in overview.entries)
        '${name(entry.item.templateId)} (${labels.planStatus(entry.status)})',
      for (final session in overview.extra)
        '${session.title ?? session.templateNameSnapshot ?? '—'} '
            '(${labels.planExtra})',
    ];
    return parts.isEmpty ? labels.planRest : parts.join(', ');
  }

  final buffer = StringBuffer()
    ..writeln()
    ..writeln('## ${labels.planSection}')
    ..writeln()
    ..writeln(labels.planWeek(start.toIso(), week.done, week.planned))
    ..writeln(labels.planStreak(planStreak(plan, byDate, today)));
  buffer.writeln();
  for (var i = 0; i < 7; i++) {
    final date = start.addDays(i);
    buffer.writeln(
      '- ${day(date)}: ${describe(dayOverview(plan, byDate, date, today))}',
    );
  }
  buffer
    ..writeln()
    ..writeln('${labels.planUpcoming}:');
  for (var i = 1; i <= 7; i++) {
    final date = today.addDays(i);
    final items = dayPlan(plan, date).items;
    if (items.isEmpty) continue;
    buffer.writeln(
      '- ${day(date)}: ${[for (final item in items) name(item.templateId)].join(', ')}',
    );
  }
  final weekly = weeklyTemplates(currentWeeklyPlan(plan.weekly, today));
  final weeklyLine = [
    for (var weekday = 1; weekday <= 7; weekday++)
      if (weekly[weekday]!.isNotEmpty)
        '${labels.weekday(weekday)}: '
            '${[for (final id in weekly[weekday]!) name(id)].join(', ')}',
  ];
  if (weeklyLine.isNotEmpty) {
    buffer
      ..writeln()
      ..writeln('${labels.planWeekly}: ${weeklyLine.join('; ')}');
  }
  return buffer.toString();
}

/// Kontekst komentarza do treningu: sam trening, porównanie każdego
/// ćwiczenia z poprzednim wykonaniem i rekordy pobite względem treningów
/// sprzed niego.
String sessionReviewContext({
  required WorkoutSession session,
  required List<WorkoutSession> history,
  required Map<String, Exercise> catalog,
  required AssistantFormat format,
}) {
  final (:labels, :unit, :locale) = format;
  final sep = labels.export.decimalSeparator;
  final buffer = StringBuffer()
    ..writeln('# ${labels.session}')
    ..writeln()
    ..writeln(labels.intro(weightUnitLabel(unit)))
    ..writeln()
    ..write(
      _demote(
        _withoutTitle(
          exportMarkdown(
            exportRows([session], const ExportFilter()),
            labels: labels.export,
            unit: unit,
            exerciseNames: _names(catalog),
          ),
        ),
      ),
    )
    ..writeln()
    ..writeln('## ${labels.compare}')
    ..writeln();

  String setsOf(SessionExercise e) => [
    for (final s in e.sets.where(countsForMetrics))
      exportSetSummary(s, e.measurementSnapshot, unit, sep),
  ].join(', ');

  for (final comparison in compareWithPrevious(session, history)) {
    final current = comparison.current;
    if (!_worked(current)) continue;
    final parts = <String>[labels.now(setsOf(current))];
    if (comparison.previous case final previous?) {
      parts.add(
        labels.previous(
          previous.session.localDate.toIso(),
          setsOf(previous.exercise),
        ),
      );
      if ((comparison.previousBestE1rmG, comparison.bestE1rmG) case (
        final before?,
        final after?,
      )) {
        parts.add(
          '${labels.e1rm} ${formatEstimate(before, unit, locale)} → '
          '${formatEstimate(after, unit, locale)}',
        );
      }
      if (hasWeightMetrics(current.loadModeSnapshot)) {
        parts.add(
          '${labels.volume} '
          '${formatVolume(comparison.previousVolumeG!, unit, locale)} → '
          '${formatVolume(comparison.volumeG, unit, locale)}',
        );
      }
    } else {
      parts.add(labels.firstTime);
    }
    buffer.writeln('- ${_name(catalog, current)}: ${parts.join('; ')}');
  }

  // Rekordy względem treningów sprzed tego.
  final earlier = <String, List<PerformedSet>>{};
  for (final other in history) {
    if (other.id == session.id ||
        !other.startedAt.isBefore(session.startedAt)) {
      continue;
    }
    for (final e in other.exercises) {
      (earlier[e.exerciseId] ??= []).addAll([
        for (final set in e.sets) (set: set, loadMode: e.loadModeSnapshot),
      ]);
    }
  }
  final records = sessionRecords(session, earlier);
  buffer
    ..writeln()
    ..writeln('## ${labels.records}')
    ..writeln();
  if (records.isEmpty) {
    buffer.writeln(labels.noRecords);
  }
  for (final (:exerciseName, :event) in records) {
    final text = switch (event) {
      E1rmRecord(:final e1rmG) =>
        '${labels.e1rm} ${formatEstimate(e1rmG, unit, locale)}',
      RepsWeightRecord(:final reps, :final weightG) =>
        '${labels.repsAtLeast(reps)}: ${formatWeight(weightG, unit, locale)}',
      MaxRepsRecord(:final reps) => '${labels.maxReps} $reps',
    };
    buffer.writeln('- $exerciseName: $text');
  }
  return buffer.toString();
}

/// Kontekst propozycji następnego treningu: plan serii każdego ćwiczenia
/// szablonu i jego ostatnie wykonania z wysiłkiem.
String nextWorkoutContext({
  required Template template,
  required List<WorkoutSession> history,
  required Map<String, Exercise> catalog,
  required AssistantFormat format,
}) {
  final (:labels, :unit, :locale) = format;
  final sep = labels.export.decimalSeparator;
  final buffer = StringBuffer()
    ..writeln('# ${labels.template(template.name)}')
    ..writeln()
    ..writeln(labels.intro(weightUnitLabel(unit)));
  final exercises = [...template.exercises]
    ..sort((a, b) => a.position.compareTo(b.position));
  for (final planned in exercises) {
    final info = catalog[planned.exerciseId];
    final performances = [
      for (final p in exercisePerformances(history, planned.exerciseId))
        if (p.exercise.sets.any((s) => s.isCompleted)) p,
    ];
    final name =
        info?.name ??
        performances.firstOrNull?.exercise.exerciseNameSnapshot ??
        planned.exerciseId;
    final sets = [
      for (final set in resolveEffectiveSets(planned)) _planSet(format, set),
    ];
    buffer
      ..writeln()
      ..writeln('## $name')
      ..writeln()
      ..writeln(labels.plan(sets.join('; ')));
    if (planned.note case final note?) buffer.writeln(note);
    buffer
      ..writeln()
      ..writeln('${labels.history}:');
    if (performances.isEmpty) buffer.writeln(labels.noHistory);
    for (final p in performances.take(assistantPerformancesPerExercise)) {
      final done = [
        for (final s in p.exercise.sets.where((s) => s.isCompleted))
          exportSetSummary(s, p.exercise.measurementSnapshot, unit, sep),
      ];
      buffer.writeln('- ${p.session.localDate.toIso()}: ${done.join(', ')}');
    }
    final best = bestEstimatedOneRepMaxOf(performances);
    if (best != null) {
      buffer.writeln('${labels.e1rm}: ${formatEstimate(best, unit, locale)}');
    }
  }
  return buffer.toString();
}

/// Najlepszy szacowany 1RM z ostatnich wykonań.
double? bestEstimatedOneRepMaxOf(List<ExercisePerformance> performances) =>
    performances
        .take(assistantPerformancesPerExercise)
        .map((p) => bestEstimatedOneRepMax(p.exercise))
        .nonNulls
        .maxOrNull;

/// Ćwiczenie z co najmniej jedną serią roboczą.
bool _worked(SessionExercise exercise) => exercise.sets.any(countsForMetrics);

String _name(Map<String, Exercise> catalog, SessionExercise exercise) =>
    catalog[exercise.exerciseId]?.name ?? exercise.exerciseNameSnapshot;

Map<String, String> _names(Map<String, Exercise> catalog) => {
  for (final e in catalog.values) e.id: e.name,
};

/// Seria planu, np. „Robocza: 8–12 powt., 80 kg, przerwa 2:30”.
String _planSet(AssistantFormat format, EffectiveSet set) {
  final (:labels, :unit, :locale) = format;
  final target = formatTarget(set.targetKind, set.targetMin, set.targetMax);
  final parts = [
    if (target.isNotEmpty)
      set.targetKind == TargetKind.reps ? '$target ${labels.repsUnit}' : target,
    if (set.targetWeightG case final weight?)
      formatWeight(weight, unit, locale),
    if (set.restSeconds case final rest?) labels.rest(formatClock(rest)),
  ];
  return '${labels.export.setTypes[set.setType] ?? ''}: ${parts.join(', ')}';
}

/// Markdown bez pierwszego nagłówka (tytułu dokumentu eksportu).
String _withoutTitle(String markdown) =>
    markdown.replaceFirst(RegExp(r'^# .*\n'), '');

/// Nagłówki Markdown eksportu o poziom niżej, żeby pasowały pod nagłówek
/// kontekstu.
String _demote(String markdown) => markdown.replaceAllMapped(
  RegExp(r'^(#+) ', multiLine: true),
  (m) => '#${m[1]} ',
);

String _metricLabel(AssistantContextLabels labels, ExerciseMetric metric) =>
    switch (metric) {
      ExerciseMetric.e1rm => labels.e1rm,
      ExerciseMetric.maxReps => labels.maxReps,
      ExerciseMetric.maxDuration => labels.maxDuration,
    };

String _metricValue(
  AssistantFormat format,
  ExerciseMetric metric,
  double value,
) => switch (metric) {
  ExerciseMetric.e1rm => formatEstimate(value, format.unit, format.locale),
  ExerciseMetric.maxReps => '${value.round()} ${format.labels.repsUnit}',
  ExerciseMetric.maxDuration => formatClock(value.round()),
};

String _bestSet(
  AssistantFormat format,
  ExerciseMetric metric,
  SessionSet set,
) => switch (metric) {
  ExerciseMetric.e1rm =>
    '${formatWeight(set.weightG ?? 0, format.unit, format.locale)} '
        '× ${set.reps ?? 0}',
  ExerciseMetric.maxReps => '${set.reps ?? 0} ${format.labels.repsUnit}',
  ExerciseMetric.maxDuration => formatClock(set.durationS ?? 0),
};

String _percent(double value, String locale) {
  final rounded = double.parse(value.toStringAsFixed(1));
  final sign = rounded > 0
      ? '+'
      : rounded < 0
      ? '−'
      : '';
  return '$sign${formatDecimal(rounded.abs(), locale, maxDecimals: 1)}%';
}
