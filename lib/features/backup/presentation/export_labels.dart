import '../../../core/domain/training.dart';
import '../../../core/domain/units.dart';
import '../../../core/l10n/formatters.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../domain/workout_export.dart';

/// Teksty eksportu Markdown/CSV w języku użytkownika; [title] zastępuje
/// nagłówek dokumentu (np. w kontekście asystenta AI).
ExportLabels exportLabels(
  AppLocalizations l10n,
  WeightUnit unit, {
  String? title,
}) {
  final unitLabel = weightUnitLabel(unit);
  return ExportLabels(
    title: title ?? l10n.exportDocTitle,
    unitsLine: l10n.exportDocUnits(unitLabel),
    date: l10n.exportColDate,
    time: l10n.exportColTime,
    workout: l10n.exportColWorkout,
    template: l10n.exportColTemplate,
    exercise: l10n.exportColExercise,
    set: l10n.exportColSet,
    setTypeHeader: l10n.exportColSetType,
    weight: l10n.exportColWeight(unitLabel),
    reps: l10n.exportColReps,
    duration: l10n.exportColDuration,
    distance: l10n.exportColDistance,
    rir: l10n.effortRir,
    rpe: l10n.effortRpe,
    notes: l10n.exportColNotes,
    sets: l10n.exportColSets,
    start: l10n.exportDocStart,
    workoutDuration: l10n.exportDocDuration,
    wellbeing: l10n.exportDocWellbeing,
    setTypes: {
      SetType.warmup: l10n.setTypeWarmup,
      SetType.working: l10n.setTypeWorking,
      SetType.drop: l10n.setTypeDrop,
      SetType.amrap: l10n.setTypeAmrap,
    },
    untitledWorkout: l10n.workoutTitle,
    decimalSeparator: formatDecimal(1.5, l10n.localeName).substring(1, 2),
  );
}
