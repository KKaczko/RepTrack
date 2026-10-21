import '../../../core/domain/training.dart';
import '../../../core/domain/units.dart';
import '../../../core/l10n/formatters.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../exercises/domain/exercise.dart';
import '../domain/session_editing.dart';
import '../domain/set_hints.dart';
import '../domain/workout_session.dart';

/// Wartości wysiłku do wyboru w dziesiątych częściach (RIR 2 → 20).
const rirChoices = <int>[0, 10, 20, 30, 40, 50];
const rpeChoices = <int>[60, 70, 75, 80, 85, 90, 95, 100];

/// Krok stepperów powtórzeń; kroki ciężaru, czasu i dystansu są
/// w ustawieniach.
const repsStep = 1;

extension WorkoutLabels on AppLocalizations {
  String fieldLabel(SetField field) => switch (field) {
    SetField.weight => measureWeight,
    SetField.reps => measureReps,
    SetField.duration => measureDuration,
    SetField.distance => measureDistance,
  };

  String effortScaleLabel(EffortScale scale) => switch (scale) {
    EffortScale.rir => effortRir,
    EffortScale.rpe => effortRpe,
  };

  /// Oznaczenie typu serii w tabeli; pusty dla serii roboczej.
  String setTypeTag(SetType type) => switch (type) {
    SetType.warmup => setLabelWarmup,
    SetType.working => '',
    SetType.drop => setLabelDrop,
    SetType.amrap => setLabelAmrap,
  };

  /// Wartość pola bez jednostki ciężaru, np. „82,5”, „10”, „1:30”, „400 m”.
  String fieldValue(
    SetField field,
    int value,
    WeightUnit unit,
    String locale,
  ) => switch (field) {
    SetField.weight => formatWeightValue(value, unit, locale),
    SetField.reps => '$value',
    SetField.duration => formatClock(value),
    SetField.distance => '$value $workoutUnitMeters',
  };

  /// Wartość pola z jednostką, do czytnika ekranu i arkuszy.
  String fieldValueWithUnit(
    SetField field,
    int value,
    WeightUnit unit,
    String locale,
  ) => switch (field) {
    SetField.weight => formatWeight(value, unit, locale),
    SetField.reps => '$value $workoutUnitReps',
    _ => fieldValue(field, value, unit, locale),
  };

  /// Nagłówek kolumny wartości, np. „kg × powt.”.
  String valuesHeader(Measurement m, WeightUnit unit) =>
      _joinFields(measuredFields(m), (field) {
        return switch (field) {
          SetField.weight => weightUnitLabel(unit),
          SetField.reps => workoutUnitReps,
          SetField.duration => measureDuration.toLowerCase(),
          SetField.distance => workoutUnitMeters,
        };
      });

  /// Wartości serii, np. „80×10” albo „30:00 · 5000 m”; null gdy brak.
  String? setValues(
    SessionSet set,
    Measurement m,
    WeightUnit unit,
    String locale,
  ) => formatSetValues(
    unit: unit,
    locale: locale,
    weightG: m.weight ? set.weightG : null,
    reps: m.reps ? set.reps : null,
    durationS: m.duration ? set.durationS : null,
    distanceM: m.distance ? set.distanceM : null,
    metersUnit: workoutUnitMeters,
  );

  /// Plan ćwiczenia, np. „3 × 8–12 · przerwa 2:00”.
  String sessionExercisePlan(SessionExercise exercise) {
    final sets = sortedSets(exercise);
    if (sets.isEmpty) return setCount(0);
    final targets = [
      for (final s in sets)
        formatTarget(s.targetKind ?? TargetKind.reps, s.targetMin, s.targetMax),
    ];
    final parts = <String>[
      if (targets.toSet().length == 1 && targets.first.isNotEmpty)
        '${sets.length} × ${targets.first}'
      else
        setCount(sets.length),
    ];
    final rests = {for (final s in sets) s.restSeconds};
    if (rests.length == 1 && rests.first != null) {
      parts.add(templateRestSummary(formatClock(rests.first!)));
    }
    return parts.join(' · ');
  }
}

/// Łączy ciężar i powtórzenia znakiem „×”, pozostałe pola kropką.
String _joinFields(
  List<SetField> fields,
  String Function(SetField field) label, {
  String times = ' × ',
}) {
  final buffer = StringBuffer();
  for (final (i, field) in fields.indexed) {
    if (i > 0) {
      final pair = fields[i - 1] == SetField.weight && field == SetField.reps;
      buffer.write(pair ? times : ' · ');
    }
    buffer.write(label(field));
  }
  return buffer.toString();
}
