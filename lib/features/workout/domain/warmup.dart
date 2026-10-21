import '../../../core/domain/units.dart';

/// Serie rozgrzewkowe przed ciężarem roboczym (ADR 0020).
typedef WarmupSet = ({int weightG, int reps});

/// Schemat: 40% × 8, 60% × 5, 80% × 3 ciężaru roboczego.
const _scheme = [(0.4, 8), (0.6, 5), (0.8, 3)];

/// Rozgrzewka przed [workingWeightG]: ciężary zaokrąglone w dół do [step]
/// (w jednostce [unit]), nie mniejsze niż [minWeight] (np. sam gryf),
/// mniejsze niż ciężar roboczy i bez powtórzeń. Przy lekkim ciężarze serii
/// jest mniej; pusta lista, gdy rozgrzewka nie ma sensu.
List<WarmupSet> warmupPlan(
  int workingWeightG, {
  required double step,
  required WeightUnit unit,
  double minWeight = 0,
}) {
  if (workingWeightG <= 0 || step <= 0) return const [];
  final working = gramsToDisplay(workingWeightG, unit);
  final result = <WarmupSet>[];
  final seen = <double>{};
  for (final (share, reps) in _scheme) {
    var weight = roundToStep(
      // Odrobina zapasu na błąd zaokrąglenia (np. 27,999… zamiast 28).
      (working * share / step + 1e-3).floorToDouble() * step,
      step,
    );
    if (weight < minWeight) weight = minWeight;
    if (weight <= 0 || weight >= working || !seen.add(weight)) continue;
    result.add((weightG: displayToGrams(weight, unit), reps: reps));
  }
  return result;
}
