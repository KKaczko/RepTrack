import 'package:collection/collection.dart';

import '../../../core/domain/ids.dart';
import '../../../core/domain/training.dart';
import '../../exercises/domain/exercise.dart';
import 'session_builder.dart';
import 'workout_session.dart';

/// Zmiany sesji w trakcie treningu (spec. 5.3): serie i ćwiczenia można
/// dodawać, usuwać, zamieniać i przestawiać. Wszystkie funkcje są czyste.

List<SessionExercise> sortedExercises(WorkoutSession session) =>
    session.exercises.sortedBy<num>((e) => e.position);

List<SessionSet> sortedSets(SessionExercise exercise) =>
    exercise.sets.sortedBy<num>((s) => s.position);

/// Zmienia ćwiczenie sesji o identyfikatorze [exerciseId].
WorkoutSession updateExercise(
  WorkoutSession session,
  String exerciseId,
  SessionExercise Function(SessionExercise e) change,
) => session.copyWith(
  exercises: [
    for (final e in sortedExercises(session))
      e.id == exerciseId ? change(e) : e,
  ],
);

/// Zmienia serię [setId] ćwiczenia [exerciseId].
WorkoutSession updateSet(
  WorkoutSession session,
  String exerciseId,
  String setId,
  SessionSet Function(SessionSet s) change,
) => updateExercise(
  session,
  exerciseId,
  (e) => e.copyWith(
    sets: [for (final s in sortedSets(e)) s.id == setId ? change(s) : s],
  ),
);

/// Dodaje serię na końcu ćwiczenia z planem skopiowanym z ostatniej serii.
WorkoutSession addSet(
  WorkoutSession session,
  String exerciseId,
  IdGenerator ids,
) => updateExercise(session, exerciseId, (e) {
  final sets = sortedSets(e);
  final last = sets.lastOrNull;
  return e.copyWith(
    sets: [
      ...sets,
      SessionSet(
        id: ids.newId(),
        position: sets.length,
        setType: last?.setType ?? SetType.working,
        targetKind: last?.targetKind,
        targetMin: last?.targetMin,
        targetMax: last?.targetMax,
        targetWeightG: last?.targetWeightG,
        restSeconds: last?.restSeconds,
      ),
    ],
  );
});

/// Usuwa serię i przenumerowuje pozostałe.
WorkoutSession removeSet(
  WorkoutSession session,
  String exerciseId,
  String setId,
) => updateExercise(
  session,
  exerciseId,
  (e) => e.copyWith(
    sets: _renumberSets(sortedSets(e).where((s) => s.id != setId).toList()),
  ),
);

/// Dodaje ćwiczenia na koniec sesji.
WorkoutSession addExercisesToSession(
  WorkoutSession session,
  Iterable<Exercise> exercises,
  IdGenerator ids,
) {
  final current = sortedExercises(session);
  return session.copyWith(
    exercises: [
      ...current,
      for (final (i, exercise) in exercises.indexed)
        newSessionExercise(exercise, position: current.length + i, ids: ids),
    ],
  );
}

/// Usuwa ćwiczenie z sesji wraz z jego seriami.
WorkoutSession removeExerciseFromSession(
  WorkoutSession session,
  String exerciseId,
) => session.copyWith(
  exercises: _renumberExercises(
    sortedExercises(session).where((e) => e.id != exerciseId).toList(),
  ),
);

/// Zamienia ćwiczenie na [replacement] (np. zajęta maszyna). Plan serii
/// zostaje, a wpisane wartości i zatwierdzenia są czyszczone, bo dotyczyły
/// innego ćwiczenia.
WorkoutSession replaceExerciseInSession(
  WorkoutSession session,
  String exerciseId,
  Exercise replacement,
) => updateExercise(session, exerciseId, (e) {
  final snapshot = snapshotExercise(
    replacement,
    id: e.id,
    position: e.position,
  );
  return snapshot.copyWith(
    templateExerciseId: e.templateExerciseId,
    note: e.note,
    groupId: e.groupId,
    sets: [
      for (final s in sortedSets(e))
        SessionSet(
          id: s.id,
          position: s.position,
          setType: s.setType,
          targetKind: s.targetKind,
          targetMin: s.targetMin,
          targetMax: s.targetMax,
          targetWeightG: s.targetWeightG,
          restSeconds: s.restSeconds,
        ),
    ],
  );
});

/// Przenosi ćwiczenie z indeksu [from] na docelowy indeks [to] w liście po
/// przeniesieniu.
WorkoutSession moveExerciseInSession(WorkoutSession session, int from, int to) {
  final list = sortedExercises(session);
  RangeError.checkValidIndex(from, list, 'from');
  RangeError.checkValidIndex(to, list, 'to');
  final moved = list.removeAt(from);
  list.insert(to, moved);
  return session.copyWith(exercises: _renumberExercises(list));
}

List<SessionSet> _renumberSets(List<SessionSet> sets) => [
  for (final (i, s) in sets.indexed)
    s.position == i ? s : s.copyWith(position: i),
];

List<SessionExercise> _renumberExercises(List<SessionExercise> list) => [
  for (final (i, e) in list.indexed)
    e.position == i ? e : e.copyWith(position: i),
];
