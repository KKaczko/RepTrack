import 'dart:math';

import 'package:collection/collection.dart';

import '../../../core/domain/local_date.dart';
import '../../exercises/domain/exercise.dart';
import '../../workout/domain/session_summary.dart';
import '../../workout/domain/workout_session.dart';
import 'metrics.dart';

/// Analiza progresu w wybranym okresie (ADR 0007): podsumowanie z porównaniem
/// do poprzedniego okresu, serie na partię mięśniową i postęp ćwiczenia.

/// Okres analizy, liczony wstecz od dziś (z dzisiejszym dniem).
enum ProgressPeriod {
  weeks4(28),
  months3(91),
  year(364),
  all(null);

  const ProgressPeriod(this.days);

  /// Długość w dniach; null oznacza całą historię.
  final int? days;
}

/// Zakres dat lokalnych (włącznie); [from] null oznacza „od początku”.
typedef DateRange = ({LocalDate? from, LocalDate to});

bool inRange(LocalDate date, DateRange range) =>
    (range.from == null || date.compareTo(range.from!) >= 0) &&
    date.compareTo(range.to) <= 0;

DateRange periodRange(ProgressPeriod period, LocalDate today) => (
  from: period.days == null ? null : today.addDays(-(period.days! - 1)),
  to: today,
);

/// Okres tej samej długości tuż przed [period]; null dla całej historii.
DateRange? previousRange(ProgressPeriod period, LocalDate today) {
  final days = period.days;
  if (days == null) return null;
  final to = today.addDays(-days);
  return (from: to.addDays(-(days - 1)), to: to);
}

/// Liczba tygodni na wykresie i w średnich: dla całej historii od tygodnia
/// pierwszego treningu (co najmniej 4).
int periodWeeks(
  ProgressPeriod period,
  List<WorkoutSession> history,
  LocalDate today,
) {
  final days = period.days;
  if (days != null) return (days / 7).ceil();
  final first = history.map((s) => s.localDate).minOrNull;
  if (first == null) return 4;
  final span = DateTime.utc(today.year, today.month, today.day)
      .difference(
        DateTime.utc(
          first.startOfWeek.year,
          first.startOfWeek.month,
          first.startOfWeek.day,
        ),
      )
      .inDays;
  return max(4, span ~/ 7 + 1);
}

/// Podsumowanie treningów w okresie.
final class PeriodSummary {
  const PeriodSummary({
    required this.workouts,
    required this.sets,
    required this.volumeG,
    required this.duration,
  });

  final int workouts;

  /// Zatwierdzone serie (z rozgrzewkami, jak na ekranie podsumowania).
  final int sets;

  /// Objętość bez rozgrzewek (ADR 0007).
  final int volumeG;
  final Duration duration;
}

PeriodSummary summarizePeriod(List<WorkoutSession> history, DateRange range) {
  var workouts = 0;
  var sets = 0;
  var volume = 0;
  var duration = Duration.zero;
  for (final session in history) {
    if (!inRange(session.localDate, range)) continue;
    final summary = summarizeSession(
      session,
      session.endedAt ?? session.startedAt,
    );
    workouts++;
    sets += summary.completedSets;
    volume += summary.volumeG;
    duration += summary.duration;
  }
  return PeriodSummary(
    workouts: workouts,
    sets: sets,
    volumeG: volume,
    duration: duration,
  );
}

/// Waga serii dla mięśnia pomocniczego (główny = 1).
const secondaryMuscleWeight = 0.5;

/// Średnia liczba zatwierdzonych serii roboczych na tydzień na partię
/// mięśniową: seria liczy się 1 dla mięśni głównych i 0,5 dla pomocniczych.
/// Mięśnie według bieżącego katalogu ćwiczeń; od największej liczby.
List<({MuscleGroup muscle, double sets})> weeklySetsPerMuscle(
  List<WorkoutSession> history,
  DateRange range,
  Map<String, Exercise> catalog,
  int weeks,
) {
  final totals = <MuscleGroup, double>{};
  for (final session in history) {
    if (!inRange(session.localDate, range)) continue;
    for (final exercise in session.exercises) {
      final info = catalog[exercise.exerciseId];
      if (info == null) continue;
      final sets = exercise.sets.where(countsForMetrics).length;
      if (sets == 0) continue;
      for (final muscle in info.primaryMuscles) {
        totals[muscle] = (totals[muscle] ?? 0) + sets;
      }
      for (final muscle in info.secondaryMuscles) {
        if (info.primaryMuscles.contains(muscle)) continue;
        totals[muscle] = (totals[muscle] ?? 0) + sets * secondaryMuscleWeight;
      }
    }
  }
  return [
    for (final MapEntry(key: muscle, value: total) in totals.entries)
      (muscle: muscle, sets: total / max(1, weeks)),
  ]..sort((a, b) => b.sets.compareTo(a.sets));
}

/// Główna miara postępu ćwiczenia.
enum ExerciseMetric {
  /// Szacowany 1RM (ciężar zewnętrzny i dociążenie).
  e1rm,

  /// Najwięcej powtórzeń w serii (masa ciała, wspomaganie).
  maxReps,

  /// Najdłuższa seria na czas (np. deska).
  maxDuration,
}

/// Miara dla ćwiczenia według pomiaru i trybu obciążenia z ostatniego
/// wykonania; null, gdy ćwiczenie nie ma żadnej (np. sam dystans).
ExerciseMetric? metricFor(SessionExercise exercise) {
  final m = exercise.measurementSnapshot;
  if (m.weight && m.reps && hasWeightMetrics(exercise.loadModeSnapshot)) {
    return ExerciseMetric.e1rm;
  }
  if (m.reps) return ExerciseMetric.maxReps;
  if (m.duration) return ExerciseMetric.maxDuration;
  return null;
}

/// Wartość miary dla jednego wykonania; null, gdy brak serii, które ją dają.
double? metricValue(SessionExercise exercise, ExerciseMetric metric) {
  final sets = exercise.sets.where(countsForMetrics);
  return switch (metric) {
    ExerciseMetric.e1rm => bestEstimatedOneRepMax(exercise),
    ExerciseMetric.maxReps =>
      sets.map((s) => s.reps).nonNulls.maxOrNull?.toDouble(),
    ExerciseMetric.maxDuration =>
      sets.map((s) => s.durationS).nonNulls.maxOrNull?.toDouble(),
  };
}

/// Najlepsza wartość miary na dzień treningu, od najstarszego.
List<ChartPoint> metricTrend(
  Iterable<({LocalDate date, SessionExercise exercise})> performances,
  ExerciseMetric metric,
) {
  final best = <LocalDate, double>{};
  for (final p in performances) {
    final value = metricValue(p.exercise, metric);
    if (value == null) continue;
    final old = best[p.date];
    if (old == null || value > old) best[p.date] = value;
  }
  return [
    for (final date in best.keys.sorted()) (date: date, value: best[date]!),
  ];
}

/// Najlepsza seria: najcięższa (przy remisie więcej powtórzeń) dla miar
/// z ciężarem, najwięcej powtórzeń albo najdłuższa dla pozostałych.
SessionSet? bestSet(
  Iterable<SessionExercise> exercises,
  ExerciseMetric metric,
) {
  final sets = exercises.expand((e) => e.sets.where(countsForMetrics));
  int compare(SessionSet a, SessionSet b) => switch (metric) {
    ExerciseMetric.e1rm =>
      (a.weightG ?? 0) != (b.weightG ?? 0)
          ? (a.weightG ?? 0).compareTo(b.weightG ?? 0)
          : (a.reps ?? 0).compareTo(b.reps ?? 0),
    ExerciseMetric.maxReps => (a.reps ?? 0).compareTo(b.reps ?? 0),
    ExerciseMetric.maxDuration => (a.durationS ?? 0).compareTo(
      b.durationS ?? 0,
    ),
  };
  return sets.isEmpty ? null : sets.reduce((a, b) => compare(b, a) > 0 ? b : a);
}

/// Postęp ćwiczenia w okresie.
final class ExerciseProgress {
  const ExerciseProgress({
    required this.metric,
    required this.trend,
    required this.best,
    required this.bestSet,
    required this.workouts,
    required this.volumeG,
  });

  final ExerciseMetric? metric;

  /// Najlepsza wartość miary na dzień, od najstarszego.
  final List<ChartPoint> trend;

  /// Najlepsza wartość miary w okresie.
  final double? best;
  final SessionSet? bestSet;

  /// Wykonania ćwiczenia w okresie (jedno na trening; dwa treningi
  /// jednego dnia to dwa wykonania).
  final int workouts;
  final int volumeG;

  /// Zmiana od pierwszego do ostatniego dnia z wynikiem w okresie, w %;
  /// null przy mniej niż dwóch dniach.
  double? get changePercent {
    if (trend.length < 2 || trend.first.value <= 0) return null;
    return (trend.last.value - trend.first.value) / trend.first.value * 100;
  }
}

/// Postęp ćwiczenia z wykonań (od najnowszego, jak w historii) w [range].
ExerciseProgress exerciseProgress(
  List<({LocalDate date, SessionExercise exercise})> performances,
  DateRange range,
) {
  final inPeriod = [
    for (final p in performances)
      if (inRange(p.date, range)) p,
  ];
  final metric = performances.isEmpty
      ? null
      : metricFor(performances.first.exercise);
  final trend = metric == null
      ? const <ChartPoint>[]
      : metricTrend(inPeriod, metric);
  return ExerciseProgress(
    metric: metric,
    trend: trend,
    best: trend.map((p) => p.value).maxOrNull,
    bestSet: metric == null
        ? null
        : bestSet(inPeriod.map((p) => p.exercise), metric),
    workouts: inPeriod.length,
    volumeG: inPeriod.fold(0, (sum, p) => sum + exerciseVolumeG(p.exercise)),
  );
}
