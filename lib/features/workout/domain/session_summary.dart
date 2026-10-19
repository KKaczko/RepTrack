import '../../progress/domain/metrics.dart';
import 'session_editing.dart';
import 'workout_session.dart';

/// Podsumowanie zakończonego treningu (spec. 5.3).
final class SessionSummary {
  const SessionSummary({
    required this.duration,
    required this.completedSets,
    required this.exercisesDone,
    required this.volumeG,
  });

  final Duration duration;
  final int completedSets;

  /// Ćwiczenia z co najmniej jedną zatwierdzoną serią.
  final int exercisesDone;

  /// Objętość bez rozgrzewek (ADR 0007).
  final int volumeG;
}

SessionSummary summarizeSession(WorkoutSession session, DateTime endedAt) {
  var sets = 0;
  var exercises = 0;
  for (final exercise in session.exercises) {
    final done = exercise.sets.where((s) => s.isCompleted).length;
    sets += done;
    if (done > 0) exercises++;
  }
  final duration = endedAt.difference(session.startedAt);
  return SessionSummary(
    duration: duration.isNegative ? Duration.zero : duration,
    completedSets: sets,
    exercisesDone: exercises,
    volumeG: sessionVolumeG(session),
  );
}

/// Rekord pobity w sesji z nazwą ćwiczenia ze snapshotu.
typedef SessionRecord = ({String exerciseName, RecordEvent event});

/// Rekordy pobite w [session] względem [history]: zatwierdzonych serii
/// z innych zakończonych sesji, według id ćwiczenia (ADR 0007).
List<SessionRecord> sessionRecords(
  WorkoutSession session,
  Map<String, List<PerformedSet>> history,
) {
  final byExercise = <String, List<SessionExercise>>{};
  for (final exercise in sortedExercises(session)) {
    (byExercise[exercise.exerciseId] ??= []).add(exercise);
  }
  return [
    for (final MapEntry(key: id, value: entries) in byExercise.entries)
      for (final event in newRecords(
        before: computeRecords(history[id] ?? const []),
        session: computeRecords([
          for (final e in entries)
            for (final set in e.sets) (set: set, loadMode: e.loadModeSnapshot),
        ]),
      ))
        (exerciseName: entries.first.exerciseNameSnapshot, event: event),
  ];
}

/// Liczba niezatwierdzonych serii w sesji.
int openSetCount(WorkoutSession session) => session.exercises.fold(
  0,
  (sum, e) => sum + e.sets.where((s) => !s.isCompleted).length,
);
