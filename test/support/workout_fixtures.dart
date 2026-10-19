import 'package:reptrack/core/domain/training.dart';
import 'package:reptrack/features/exercises/domain/exercise.dart';
import 'package:reptrack/features/templates/domain/set_plan.dart';
import 'package:reptrack/features/templates/domain/template.dart';

import 'fakes.dart';

const bench = Exercise(
  id: 'bench',
  name: 'Wyciskanie',
  equipment: Equipment.barbell,
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
