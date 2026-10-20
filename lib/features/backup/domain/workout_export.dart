import 'package:collection/collection.dart';

import '../../../core/domain/local_date.dart';
import '../../../core/domain/training.dart';
import '../../../core/domain/units.dart';
import '../../exercises/domain/exercise.dart';
import '../../workout/domain/session_editing.dart';
import '../../workout/domain/session_summary.dart';
import '../../workout/domain/workout_session.dart';

/// Eksport treningów do CSV i Markdown (spec. 6, ADR 0008). W odróżnieniu
/// od kopii zapasowej obejmuje tylko zatwierdzone serie zakończonych
/// treningów i ma filtry okresu oraz ćwiczeń.

/// Filtr eksportu: okres (daty lokalne treningów, włącznie) i ćwiczenia.
final class ExportFilter {
  const ExportFilter({this.from, this.to, this.exerciseIds});

  final LocalDate? from;
  final LocalDate? to;

  /// Id ćwiczeń z biblioteki; null oznacza wszystkie.
  final Set<String>? exerciseIds;

  bool includesDate(LocalDate date) =>
      (from == null || date.compareTo(from!) >= 0) &&
      (to == null || date.compareTo(to!) <= 0);

  bool includesExercise(String exerciseId) =>
      exerciseIds == null || exerciseIds!.contains(exerciseId);
}

/// Teksty eksportu w języku użytkownika (dostarcza warstwa prezentacji).
final class ExportLabels {
  const ExportLabels({
    required this.title,
    required this.unitsLine,
    required this.date,
    required this.time,
    required this.workout,
    required this.template,
    required this.exercise,
    required this.set,
    required this.setTypeHeader,
    required this.weight,
    required this.reps,
    required this.duration,
    required this.distance,
    required this.rir,
    required this.rpe,
    required this.notes,
    required this.sets,
    required this.start,
    required this.workoutDuration,
    required this.wellbeing,
    required this.setTypes,
    required this.untitledWorkout,
    required this.decimalSeparator,
  });

  /// Nagłówek dokumentu Markdown.
  final String title;

  /// Zdanie o jednostkach na początku dokumentu Markdown.
  final String unitsLine;
  final String date;
  final String time;
  final String workout;
  final String template;
  final String exercise;
  final String set;
  final String setTypeHeader;

  /// Nagłówek ciężaru z jednostką, np. „Ciężar (kg)”.
  final String weight;
  final String reps;
  final String duration;
  final String distance;
  final String rir;
  final String rpe;
  final String notes;

  /// Nagłówek kolumny z seriami w układzie „per ćwiczenie”.
  final String sets;
  final String start;
  final String workoutDuration;
  final String wellbeing;
  final Map<SetType, String> setTypes;
  final String untitledWorkout;

  /// Separator dziesiętny Markdown (CSV zawsze używa przecinka).
  final String decimalSeparator;
}

/// Jedna zatwierdzona seria do eksportu.
typedef ExportRow = ({
  WorkoutSession session,
  SessionExercise exercise,
  SessionSet set,
});

/// Zatwierdzone serie zakończonych treningów spełniające filtr, od
/// najstarszego treningu, w kolejności ćwiczeń i serii.
List<ExportRow> exportRows(List<WorkoutSession> sessions, ExportFilter filter) {
  final ordered = sessions
      .where(
        (s) =>
            s.status == SessionStatus.completed &&
            filter.includesDate(s.localDate),
      )
      .sortedBy((s) => s.startedAt);
  return [
    for (final session in ordered)
      for (final exercise in sortedExercises(session))
        if (filter.includesExercise(exercise.exerciseId))
          for (final set in sortedSets(exercise))
            if (set.isCompleted)
              (session: session, exercise: exercise, set: set),
  ];
}

/// CSV dla polskiego Excela (ADR 0008): średnik, UTF-8 z BOM, przecinek
/// dziesiętny, jednostki w nagłówkach, CRLF, jeden wiersz na serię.
String exportCsv(
  List<ExportRow> rows, {
  required ExportLabels labels,
  required WeightUnit unit,
  required Map<String, String> exerciseNames,
}) {
  final buffer = StringBuffer('﻿');
  void line(List<String?> cells) {
    buffer
      ..write(cells.map((c) => _csvCell(c ?? '')).join(';'))
      ..write('\r\n');
  }

  line([
    labels.date,
    labels.time,
    labels.workout,
    labels.template,
    labels.exercise,
    labels.set,
    labels.setTypeHeader,
    labels.weight,
    labels.reps,
    labels.duration,
    labels.distance,
    labels.rir,
    labels.rpe,
    labels.notes,
  ]);
  for (final (:session, :exercise, :set) in rows) {
    line([
      session.localDate.toIso(),
      _time(session),
      session.title ?? labels.untitledWorkout,
      session.templateNameSnapshot,
      exerciseNames[exercise.exerciseId] ?? exercise.exerciseNameSnapshot,
      '${set.position + 1}',
      labels.setTypes[set.setType],
      _weight(set.weightG, unit, ','),
      set.reps?.toString(),
      set.durationS?.toString(),
      set.distanceM?.toString(),
      set.effortScale == EffortScale.rir ? _effort(set, ',') : null,
      set.effortScale == EffortScale.rpe ? _effort(set, ',') : null,
      session.notes,
    ]);
  }
  return buffer.toString();
}

/// Układ dokumentu Markdown.
enum MarkdownLayout {
  /// Sekcja na trening, tabela na ćwiczenie.
  perSession,

  /// Sekcja na ćwiczenie, wiersz na trening.
  perExercise,
}

/// Markdown do wklejenia w czat z modelem językowym: tabele z jawnymi
/// jednostkami (spec. 6).
String exportMarkdown(
  List<ExportRow> rows, {
  required ExportLabels labels,
  required WeightUnit unit,
  required Map<String, String> exerciseNames,
  MarkdownLayout layout = MarkdownLayout.perSession,
}) {
  final buffer = StringBuffer()
    ..writeln('# ${labels.title}')
    ..writeln()
    ..writeln(labels.unitsLine);
  String name(SessionExercise e) =>
      _md(exerciseNames[e.exerciseId] ?? e.exerciseNameSnapshot);
  final sep = labels.decimalSeparator;

  switch (layout) {
    case MarkdownLayout.perSession:
      for (final sessionRows in _groupBy(rows, (r) => r.session.id)) {
        final session = sessionRows.first.session;
        final summary = summarizeSession(
          session,
          session.endedAt ?? session.startedAt,
        );
        buffer
          ..writeln()
          ..writeln(
            '## ${session.localDate.toIso()} · '
            '${_md(session.title ?? labels.untitledWorkout)}',
          )
          ..writeln()
          ..writeln(
            [
              '${labels.start} ${_time(session)}',
              '${labels.workoutDuration} ${summary.duration.inMinutes} min',
              if (session.templateNameSnapshot case final t?)
                '${labels.template} ${_md(t)}',
              if (session.wellbeing case final w?) '${labels.wellbeing} $w/5',
            ].join(' · '),
          );
        if (session.notes case final notes?) {
          buffer
            ..writeln()
            ..writeln('${labels.notes}: ${_md(notes)}');
        }
        for (final exerciseRows in _groupBy(
          sessionRows,
          (r) => r.exercise.id,
        )) {
          final exercise = exerciseRows.first.exercise;
          final m = exercise.measurementSnapshot;
          final sets = [for (final r in exerciseRows) r.set];
          final scales = {for (final s in sets) ?s.effortScale};
          final columns = <(String, String Function(SessionSet))>[
            (labels.set, (s) => '${s.position + 1}'),
            (labels.setTypeHeader, (s) => labels.setTypes[s.setType] ?? ''),
            if (m.weight)
              (labels.weight, (s) => _weight(s.weightG, unit, sep) ?? ''),
            if (m.reps) (labels.reps, (s) => s.reps?.toString() ?? ''),
            if (m.duration)
              (labels.duration, (s) => s.durationS?.toString() ?? ''),
            if (m.distance)
              (labels.distance, (s) => s.distanceM?.toString() ?? ''),
            if (scales.contains(EffortScale.rir))
              (
                labels.rir,
                (s) => s.effortScale == EffortScale.rir ? _effort(s, sep)! : '',
              ),
            if (scales.contains(EffortScale.rpe))
              (
                labels.rpe,
                (s) => s.effortScale == EffortScale.rpe ? _effort(s, sep)! : '',
              ),
          ];
          buffer
            ..writeln()
            ..writeln('### ${name(exercise)}')
            ..writeln()
            ..writeln('| ${columns.map((c) => c.$1).join(' | ')} |')
            ..writeln('|${columns.map((_) => ' --- ').join('|')}|');
          for (final set in sets) {
            buffer.writeln(
              '| ${columns.map((c) => _md(c.$2(set))).join(' | ')} |',
            );
          }
        }
      }
    case MarkdownLayout.perExercise:
      final byExercise = _groupBy(rows, (r) => r.exercise.exerciseId)
        ..sort(
          (a, b) => name(a.first.exercise).compareTo(name(b.first.exercise)),
        );
      for (final exerciseRows in byExercise) {
        final exercise = exerciseRows.first.exercise;
        buffer
          ..writeln()
          ..writeln('## ${name(exercise)}')
          ..writeln()
          ..writeln('| ${labels.date} | ${labels.workout} | ${labels.sets} |')
          ..writeln('| --- | --- | --- |');
        for (final sessionRows in _groupBy(
          exerciseRows,
          (r) => r.exercise.id,
        )) {
          final session = sessionRows.first.session;
          final m = sessionRows.first.exercise.measurementSnapshot;
          final sets = sessionRows
              .map((r) => _setSummary(r.set, m, unit, sep))
              .join(', ');
          buffer.writeln(
            '| ${session.localDate.toIso()} | '
            '${_md(session.title ?? labels.untitledWorkout)} | ${_md(sets)} |',
          );
        }
      }
  }
  return buffer.toString();
}

/// Seria w jednym polu, np. „80×10”, „45 s”, „400 m”, z wysiłkiem
/// „@RIR 2”.
String _setSummary(SessionSet s, Measurement m, WeightUnit unit, String sep) {
  final load = [
    if (m.weight && s.weightG != null) _weight(s.weightG, unit, sep),
    if (m.reps && s.reps != null) '${s.reps}',
  ].join('×');
  final parts = [
    if (load.isNotEmpty) load,
    if (m.duration && s.durationS != null) '${s.durationS} s',
    if (m.distance && s.distanceM != null) '${s.distanceM} m',
  ];
  final effort = _effort(s, sep);
  if (effort != null) {
    parts.add('@${s.effortScale!.code.toUpperCase()} $effort');
  }
  return parts.join(' ');
}

/// Grupy kolejnych wierszy o tym samym kluczu, z zachowaniem kolejności
/// pierwszego wystąpienia.
List<List<ExportRow>> _groupBy(
  List<ExportRow> rows,
  String Function(ExportRow row) key,
) {
  final groups = <String, List<ExportRow>>{};
  for (final row in rows) {
    (groups[key(row)] ??= []).add(row);
  }
  return groups.values.toList();
}

String _time(WorkoutSession session) {
  final t = localTimeFor(session.startedAt, session.timeZone);
  return '${t.hour.toString().padLeft(2, '0')}:'
      '${t.minute.toString().padLeft(2, '0')}';
}

String? _weight(int? grams, WeightUnit unit, String sep) =>
    grams == null ? null : _decimal(gramsToDisplay(grams, unit), sep);

String? _effort(SessionSet set, String sep) {
  final tenths = set.effortTenths;
  if (tenths == null || set.effortScale == null) return null;
  return _decimal(tenths / 10, sep);
}

/// Liczba z najwyżej dwoma miejscami po przecinku, bez zbędnych zer
/// i bez separatora tysięcy (łatwa do przeliczenia w arkuszu).
String _decimal(double value, String sep) {
  var text = value.toStringAsFixed(2);
  if (text.contains('.')) {
    text = text
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }
  return text.replaceAll('.', sep);
}

String _csvCell(String value) {
  if (!value.contains(RegExp('[;"\r\n]'))) return value;
  return '"${value.replaceAll('"', '""')}"';
}

/// Tekst bezpieczny w komórce tabeli Markdown.
String _md(String value) =>
    value.replaceAll('|', r'\|').replaceAll(RegExp(r'\s*[\r\n]+\s*'), ' ');
