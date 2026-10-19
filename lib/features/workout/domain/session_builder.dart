import 'package:collection/collection.dart';

import '../../../core/domain/ids.dart';
import '../../../core/domain/local_date.dart';
import '../../../core/domain/training.dart';
import '../../exercises/domain/exercise.dart';
import '../../templates/domain/set_plan.dart';
import '../../templates/domain/template.dart';
import 'workout_session.dart';

/// Tworzy aktywną sesję z szablonu: niezależną kopię efektywnego planu serii
/// i snapshot ustawień ćwiczeń z chwili startu. Późniejsze zmiany szablonu
/// i ćwiczeń nie wpływają na sesję (spec. 4).
///
/// Ćwiczenia, których nie ma w [exercises], są pomijane.
WorkoutSession buildSessionFromTemplate({
  required Template template,
  required Map<String, Exercise> exercises,
  required IdGenerator ids,
  required DateTime startedAt,
  required String timeZone,
}) {
  final sessionExercises = <SessionExercise>[];
  for (final te in template.exercises.sortedBy<num>((e) => e.position)) {
    final exercise = exercises[te.exerciseId];
    if (exercise == null) continue;
    sessionExercises.add(
      _snapshot(
        exercise,
        id: ids.newId(),
        position: sessionExercises.length,
        templateExerciseId: te.id,
        note: te.note,
        groupId: te.groupId,
        sets: [
          for (final s in resolveEffectiveSets(te))
            SessionSet(
              id: ids.newId(),
              position: s.index,
              setType: s.setType,
              targetKind: s.targetKind,
              targetMin: s.targetMin,
              targetMax: s.targetMax,
              targetWeightG: s.targetWeightG,
              restSeconds: s.restSeconds,
            ),
        ],
      ),
    );
  }
  return WorkoutSession(
    id: ids.newId(),
    status: SessionStatus.active,
    startedAt: startedAt.toUtc(),
    timeZone: timeZone,
    localDate: localDateFor(startedAt, timeZone),
    templateId: template.id,
    templateNameSnapshot: template.name,
    title: template.name,
    exercises: sessionExercises,
  );
}

/// Pusty trening bez szablonu.
WorkoutSession buildEmptySession({
  required IdGenerator ids,
  required DateTime startedAt,
  required String timeZone,
}) => WorkoutSession(
  id: ids.newId(),
  status: SessionStatus.active,
  startedAt: startedAt.toUtc(),
  timeZone: timeZone,
  localDate: localDateFor(startedAt, timeZone),
);

/// Ćwiczenie dodane w trakcie treningu: serie bez celu, z liczbą zależną od
/// pomiaru (kardio 1 seria, pozostałe 3).
SessionExercise newSessionExercise(
  Exercise exercise, {
  required int position,
  required IdGenerator ids,
}) {
  final cardioLike =
      exercise.category == ExerciseCategory.cardio &&
      !exercise.measurement.reps;
  final count = cardioLike ? 1 : 3;
  final kind = exercise.measurement.reps
      ? TargetKind.reps
      : TargetKind.duration;
  return _snapshot(
    exercise,
    id: ids.newId(),
    position: position,
    sets: [
      for (var i = 0; i < count; i++)
        SessionSet(id: ids.newId(), position: i, targetKind: kind),
    ],
  );
}

/// Snapshot ćwiczenia z chwili dodania do sesji.
SessionExercise snapshotExercise(
  Exercise exercise, {
  required String id,
  required int position,
  List<SessionSet> sets = const [],
}) => _snapshot(exercise, id: id, position: position, sets: sets);

SessionExercise _snapshot(
  Exercise exercise, {
  required String id,
  required int position,
  required List<SessionSet> sets,
  String? templateExerciseId,
  String? note,
  String? groupId,
}) => SessionExercise(
  id: id,
  exerciseId: exercise.id,
  position: position,
  templateExerciseId: templateExerciseId,
  exerciseNameSnapshot: exercise.name,
  measurementSnapshot: exercise.measurement,
  loadModeSnapshot: exercise.loadMode,
  weightSemanticsSnapshot: exercise.weightSemantics,
  isUnilateralSnapshot: exercise.isUnilateral,
  note: note,
  groupId: groupId,
  sets: sets,
);
