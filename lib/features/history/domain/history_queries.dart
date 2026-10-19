import 'package:collection/collection.dart';

import '../../../core/domain/local_date.dart';
import '../../progress/domain/metrics.dart';
import '../../workout/domain/session_editing.dart';
import '../../workout/domain/workout_session.dart';

/// Zapytania o historię treningów liczone w pamięci na liście zakończonych
/// sesji (od najnowszej), tej samej, którą pokazuje zakładka Historia.

/// Jedno wykonanie ćwiczenia: sesja i ćwiczenie w tej sesji.
typedef ExercisePerformance = ({
  WorkoutSession session,
  SessionExercise exercise,
});

/// Wykonania ćwiczenia od najnowszego. Ćwiczenie dodane dwa razy w jednej
/// sesji daje dwa wykonania.
List<ExercisePerformance> exercisePerformances(
  List<WorkoutSession> history,
  String exerciseId,
) => [
  for (final session in history)
    for (final exercise in sortedExercises(session))
      if (exercise.exerciseId == exerciseId)
        (session: session, exercise: exercise),
];

/// Ostatnie wykonanie ćwiczenia przed rozpoczęciem [session] (ADR 0006:
/// ostatnia zakończona sesja z ćwiczeniem, niezależnie od szablonu).
ExercisePerformance? previousPerformance(
  List<WorkoutSession> history,
  String exerciseId,
  WorkoutSession session,
) {
  for (final other in history) {
    if (other.id == session.id ||
        !other.startedAt.isBefore(session.startedAt)) {
      continue;
    }
    final exercise = sortedExercises(other)
        .firstWhereOrNull((e) => e.exerciseId == exerciseId);
    if (exercise != null) return (session: other, exercise: exercise);
  }
  return null;
}

/// Porównanie jednego ćwiczenia z poprzednim wykonaniem.
final class ExerciseComparison {
  const ExerciseComparison({required this.current, required this.previous});

  final SessionExercise current;
  final ExercisePerformance? previous;

  int get volumeG => exerciseVolumeG(current);

  int? get previousVolumeG =>
      previous == null ? null : exerciseVolumeG(previous!.exercise);

  double? get bestE1rmG => bestEstimatedOneRepMax(current);

  double? get previousBestE1rmG =>
      previous == null ? null : bestEstimatedOneRepMax(previous!.exercise);
}

/// Porównanie treningu z poprzednim, ćwiczenie po ćwiczeniu (spec. 5.4).
List<ExerciseComparison> compareWithPrevious(
  WorkoutSession session,
  List<WorkoutSession> history,
) => [
  for (final exercise in sortedExercises(session))
    ExerciseComparison(
      current: exercise,
      previous: previousPerformance(history, exercise.exerciseId, session),
    ),
];

/// Liczba treningów w każdym z ostatnich [weeks] tygodni (od poniedziałku),
/// od najstarszego. Ostatni element to bieżący tydzień.
List<({LocalDate weekStart, int count})> workoutsPerWeek(
  List<WorkoutSession> history,
  LocalDate today, {
  int weeks = 12,
}) {
  final current = today.startOfWeek;
  final counts = <LocalDate, int>{};
  for (final session in history) {
    final week = session.localDate.startOfWeek;
    counts[week] = (counts[week] ?? 0) + 1;
  }
  return [
    for (var i = weeks - 1; i >= 0; i--)
      (
        weekStart: current.addDays(-7 * i),
        count: counts[current.addDays(-7 * i)] ?? 0,
      ),
  ];
}

/// Id szablonów od ostatnio użytego (na podstawie zakończonych treningów).
List<String> templatesByLastUse(List<WorkoutSession> history) {
  final seen = <String>{};
  return [
    for (final session in history)
      if (session.templateId case final id? when seen.add(id)) id,
  ];
}
