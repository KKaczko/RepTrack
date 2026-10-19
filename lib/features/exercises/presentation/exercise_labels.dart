import '../../../core/l10n/generated/app_localizations.dart';
import '../domain/exercise.dart';

/// Zlokalizowane etykiety enumów ćwiczeń.
extension ExerciseLabels on AppLocalizations {
  String muscle(MuscleGroup value) => switch (value) {
    MuscleGroup.abdominals => muscleAbdominals,
    MuscleGroup.abductors => muscleAbductors,
    MuscleGroup.adductors => muscleAdductors,
    MuscleGroup.biceps => muscleBiceps,
    MuscleGroup.calves => muscleCalves,
    MuscleGroup.chest => muscleChest,
    MuscleGroup.forearms => muscleForearms,
    MuscleGroup.glutes => muscleGlutes,
    MuscleGroup.hamstrings => muscleHamstrings,
    MuscleGroup.lats => muscleLats,
    MuscleGroup.lowerBack => muscleLowerBack,
    MuscleGroup.middleBack => muscleMiddleBack,
    MuscleGroup.neck => muscleNeck,
    MuscleGroup.quadriceps => muscleQuadriceps,
    MuscleGroup.shoulders => muscleShoulders,
    MuscleGroup.traps => muscleTraps,
    MuscleGroup.triceps => muscleTriceps,
  };

  String equipment(Equipment value) => switch (value) {
    Equipment.barbell => equipmentBarbell,
    Equipment.dumbbell => equipmentDumbbell,
    Equipment.kettlebell => equipmentKettlebell,
    Equipment.cable => equipmentCable,
    Equipment.machine => equipmentMachine,
    Equipment.smithMachine => equipmentSmithMachine,
    Equipment.ezBar => equipmentEzBar,
    Equipment.bodyweight => equipmentBodyweight,
    Equipment.bands => equipmentBands,
    Equipment.medicineBall => equipmentMedicineBall,
    Equipment.exerciseBall => equipmentExerciseBall,
    Equipment.foamRoll => equipmentFoamRoll,
    Equipment.other => equipmentOther,
  };

  String category(ExerciseCategory value) => switch (value) {
    ExerciseCategory.strength => categoryStrength,
    ExerciseCategory.cardio => categoryCardio,
    ExerciseCategory.mobility => categoryMobility,
    ExerciseCategory.plyometrics => categoryPlyometrics,
    ExerciseCategory.olympic => categoryOlympic,
    ExerciseCategory.strongman => categoryStrongman,
  };

  String mechanic(Mechanic value) => switch (value) {
    Mechanic.compound => mechanicCompound,
    Mechanic.isolation => mechanicIsolation,
  };

  String force(Force value) => switch (value) {
    Force.push => forcePush,
    Force.pull => forcePull,
    Force.static => forceStatic,
  };

  String loadMode(LoadMode value) => switch (value) {
    LoadMode.external => loadModeExternal,
    LoadMode.bodyweight => loadModeBodyweight,
    LoadMode.weightedBodyweight => loadModeWeightedBodyweight,
    LoadMode.assisted => loadModeAssisted,
  };

  String weightSemantics(WeightSemantics value) => switch (value) {
    WeightSemantics.total => weightSemanticsTotal,
    WeightSemantics.perHand => weightSemanticsPerHand,
    WeightSemantics.perSide => weightSemanticsPerSide,
  };

  String measurement(Measurement value) => [
    if (value.weight) measureWeight,
    if (value.reps) measureReps,
    if (value.duration) measureDuration,
    if (value.distance) measureDistance,
  ].join(', ');

  /// Krótki opis na liście: mięśnie główne i sprzęt.
  String exerciseSummary(Exercise exercise) => [
    exercise.primaryMuscles.map(muscle).join(', '),
    if (exercise.equipment != null) equipment(exercise.equipment!),
  ].where((part) => part.isNotEmpty).join(' · ');
}
