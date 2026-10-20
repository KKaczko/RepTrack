import 'package:reptrack/core/domain/training.dart';
import 'package:reptrack/features/exercises/domain/exercise.dart';
import 'package:reptrack/features/templates/domain/set_plan.dart';
import 'package:reptrack/features/templates/domain/template.dart';
import 'package:reptrack/features/workout/domain/session_builder.dart';
import 'package:reptrack/features/workout/domain/session_editing.dart';
import 'package:reptrack/features/workout/domain/workout_session.dart';

import 'fakes.dart';

const bench = Exercise(
  id: 'bench',
  name: 'Wyciskanie',
  equipment: Equipment.barbell,
  primaryMuscles: [MuscleGroup.chest],
  secondaryMuscles: [MuscleGroup.triceps, MuscleGroup.shoulders],
);
const pullUp = Exercise(
  id: 'pullup',
  name: 'Podciąganie',
  loadMode: LoadMode.weightedBodyweight,
);
const pushUp = Exercise(
  id: 'pushup',
  name: 'Pompki',
  measurement: Measurement.repsOnly,
  loadMode: LoadMode.bodyweight,
);
const plank = Exercise(
  id: 'plank',
  name: 'Deska',
  measurement: Measurement.durationOnly,
  loadMode: LoadMode.bodyweight,
);
const run = Exercise(
  id: 'run',
  name: 'Bieg',
  category: ExerciseCategory.cardio,
  measurement: Measurement(duration: true, distance: true),
  loadMode: LoadMode.bodyweight,
);

const catalog = {
  'bench': bench,
  'pullup': pullUp,
  'pushup': pushUp,
  'plank': plank,
  'run': run,
};

/// Szablon: rozgrzewka + 3 × 8–12 na ławce (80 kg, przerwa 150 s),
/// podciąganie 3 × 6–10 z ostatnią serią AMRAP.
Template pushTemplate() {
  final ids = SequentialIds('tpl');
  var benchTe = TemplateExercise(
    id: 'te-bench',
    exerciseId: 'bench',
    position: 0,
    targetMin: 8,
    targetMax: 12,
    targetWeightG: 80000,
    restSeconds: 150,
    sets: [
      for (var i = 0; i < 4; i++) TemplateSet(id: ids.newId(), position: i),
    ],
  );
  benchTe = overrideSet(
    benchTe,
    0,
    setType: SetType.warmup,
    target: (min: 10, max: 10),
    targetWeightG: 40000,
  );
  var pullTe = TemplateExercise(
    id: 'te-pull',
    exerciseId: 'pullup',
    position: 1,
    targetMin: 6,
    targetMax: 10,
    note: 'Pełny zwis',
    sets: [
      for (var i = 0; i < 3; i++) TemplateSet(id: ids.newId(), position: i),
    ],
  );
  pullTe = overrideSet(pullTe, 2, setType: SetType.amrap);
  return Template(id: 'tpl', name: 'Push A', exercises: [benchTe, pullTe]);
}

/// Zakończony trening „Push A” z zatwierdzonymi seriami roboczymi ławki
/// (gramy, powtórzenia); rozgrzewka i podciąganie bez zatwierdzeń.
WorkoutSession finishedPush(
  String prefix,
  DateTime start,
  List<(int, int)> benchSets,
) {
  var session = buildSessionFromTemplate(
    template: pushTemplate(),
    exercises: catalog,
    ids: SequentialIds(prefix),
    startedAt: start,
    timeZone: 'Europe/Warsaw',
  );
  final benchEx = sortedExercises(session).first;
  for (final (i, (weight, reps)) in benchSets.indexed) {
    session = updateSet(
      session,
      benchEx.id,
      sortedSets(benchEx)[i + 1].id,
      (s) => s.copyWith(
        weightG: weight,
        reps: reps,
        completedAt: start.add(Duration(minutes: 5 + i * 3)),
      ),
    );
  }
  return session.copyWith(
    status: SessionStatus.completed,
    endedAt: start.add(const Duration(minutes: 50)),
  );
}
