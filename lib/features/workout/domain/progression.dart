import 'package:collection/collection.dart';

import '../../../core/domain/training.dart';
import '../../../core/domain/units.dart';
import '../../exercises/domain/exercise.dart';
import 'set_hints.dart';
import 'workout_session.dart';

/// Progresja podwójna (ADR 0017): najpierw powtórzenia w zakresie, potem
/// ciężar. Liczona z poprzedniego wykonania, bez AI.

/// Dlaczego podpowiedź zmienia ciężar względem poprzedniego wykonania.
enum ProgressionReason {
  /// Każda seria robocza doszła do górnej granicy zakresu powtórzeń.
  topOfRange,

  /// Każda seria robocza w zakresie i z dużym zapasem (RIR ≥ 3, RPE ≤ 7).
  easyEffort,

  /// Dwa ostatnie wykonania przy tym samym ciężarze poniżej dolnej granicy
  /// zakresu: ciężar spada o ok. 10% (ADR 0020).
  deload,
}

/// Porada dla serii roboczych: [weightG] zamiast ciężaru z poprzedniego
/// wykonania i dolna granica zakresu powtórzeń. Przy wspomaganiu
/// [weightG] jest mniejsze (mniej wspomagania).
typedef ProgressionAdvice = ({
  int weightG,
  int previousWeightG,
  int previousSets,

  /// Najmniej powtórzeń w poprzednich seriach roboczych.
  int previousReps,
  ProgressionReason reason,
});

/// Seria z dużym zapasem: RIR co najmniej 3 albo RPE co najwyżej 7.
bool _withReserve(SessionSet set) => switch (set.effortScale) {
  EffortScale.rir => (set.effortTenths ?? -1) >= 30,
  EffortScale.rpe => (set.effortTenths ?? 1000) <= 70,
  null => false,
};

/// Porada progresji dla [exercise] na podstawie zatwierdzonych serii
/// poprzedniego wykonania. Null, gdy ciężar zostaje jak ostatnio:
/// ćwiczenie bez ciężaru i powtórzeń, seria robocza bez celu powtórzeń
/// albo bez poprzedniego wyniku, różne ciężary w seriach, wynik poniżej
/// góry zakresu (i bez dużego zapasu).
///
/// [step] to krok ciężaru w jednostce [unit] (z ustawień), więc nowy
/// ciężar leży na siatce talerzy użytkownika także w funtach.
ProgressionAdvice? progressionFor(
  SessionExercise exercise,
  List<SessionSet> previousSets, {
  required double step,
  required WeightUnit unit,
  List<SessionSet> earlierSets = const [],
}) {
  final measurement = exercise.measurementSnapshot;
  if (!measurement.weight || !measurement.reps || step <= 0) return null;
  final working = exercise.sets.whereNot(isWarmup).toList();
  if (working.isEmpty) return null;
  final matched = matchPreviousSets(exercise.sets, previousSets);
  final pairs = <({SessionSet now, SessionSet before})>[];
  for (final set in working) {
    final before = matched[set.id];
    if (before == null ||
        set.targetKind != TargetKind.reps ||
        set.targetMax == null ||
        before.weightG == null ||
        before.reps == null) {
      return null;
    }
    pairs.add((now: set, before: before));
  }
  final weights = {for (final p in pairs) p.before.weightG!};
  if (weights.length != 1) return null;
  final weight = weights.single;

  final atTop = pairs.every((p) => p.before.reps! >= p.now.targetMax!);
  final withReserve = pairs.every(
    (p) =>
        p.before.reps! >= (p.now.targetMin ?? p.now.targetMax!) &&
        _withReserve(p.before),
  );
  final assisted = exercise.loadModeSnapshot == LoadMode.assisted;
  if (!atTop && !withReserve) {
    return assisted
        ? null
        : _deload(exercise, pairs, earlierSets, weight, step, unit);
  }

  if (assisted && weight == 0) return null;
  final next = displayToGrams(
    stepValue(gramsToDisplay(weight, unit), step, assisted ? -1 : 1),
    unit,
  );
  if (next == weight) return null;
  return (
    weightG: next,
    previousWeightG: weight,
    previousSets: pairs.length,
    previousReps: pairs.map((p) => p.before.reps!).min,
    reason: atTop ? ProgressionReason.topOfRange : ProgressionReason.easyEffort,
  );
}

/// Seria robocza poniżej dolnej granicy zakresu bieżącego planu.
bool _below(SessionSet now, SessionSet before) =>
    before.reps! < (now.targetMin ?? now.targetMax!);

/// Deload: w poprzednim i wcześniejszym wykonaniu przy tym samym ciężarze
/// choć jedna seria robocza była poniżej zakresu. Ciężar × 0,9 w dół do
/// kroku, powtórzenia = dolna granica.
ProgressionAdvice? _deload(
  SessionExercise exercise,
  List<({SessionSet now, SessionSet before})> pairs,
  List<SessionSet> earlierSets,
  int weight,
  double step,
  WeightUnit unit,
) {
  if (weight <= 0 || !pairs.any((p) => _below(p.now, p.before))) return null;
  final earlier = matchPreviousSets(exercise.sets, earlierSets);
  final earlierPairs = [
    for (final p in pairs)
      if (earlier[p.now.id] case final before?
          when before.weightG != null && before.reps != null)
        (now: p.now, before: before),
  ];
  if (earlierPairs.isEmpty ||
      earlierPairs.any((p) => p.before.weightG != weight) ||
      !earlierPairs.any((p) => _below(p.now, p.before))) {
    return null;
  }
  final display = gramsToDisplay(weight, unit);
  var next = roundToStep(
    (display * 0.9 / step + 1e-3).floorToDouble() * step,
    step,
  );
  if (next >= display) next = stepValue(display, step, -1);
  if (next <= 0) return null;
  return (
    weightG: displayToGrams(next, unit),
    previousWeightG: weight,
    previousSets: pairs.length,
    previousReps: pairs.map((p) => p.before.reps!).min,
    reason: ProgressionReason.deload,
  );
}
