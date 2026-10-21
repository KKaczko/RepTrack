import 'package:flutter_test/flutter_test.dart';
import 'package:reptrack/core/domain/units.dart';
import 'package:reptrack/features/workout/domain/warmup.dart';

List<(int, int)> _plan(
  int workingG, {
  double step = 2.5,
  WeightUnit unit = WeightUnit.kg,
  double minWeight = 0,
}) => [
  for (final w in warmupPlan(
    workingG,
    step: step,
    unit: unit,
    minWeight: minWeight,
  ))
    (w.weightG, w.reps),
];

void main() {
  test('sztanga 100 kg: 40 × 8, 60 × 5, 80 × 3', () {
    expect(_plan(100000, minWeight: 20), [(40000, 8), (60000, 5), (80000, 3)]);
  });

  test('zaokrąglenie w dół do kroku i nie mniej niż gryf', () {
    // 82,5 kg: 33 → 32,5; 49,5 → 47,5; 66 → 65.
    expect(_plan(82500, minWeight: 20), [(32500, 8), (47500, 5), (65000, 3)]);
    // 30 kg: 12 i 18 to mniej niż gryf (20, raz), 24 → 22,5.
    expect(_plan(30000, minWeight: 20), [(20000, 8), (22500, 3)]);
  });

  test('hantle co 2 kg i lekki ciężar bez rozgrzewki', () {
    expect(_plan(10000, step: 2), [(4000, 8), (6000, 5), (8000, 3)]);
    expect(_plan(2500), isEmpty);
    expect(_plan(0), isEmpty);
  });

  test('funty: krok 5 lb', () {
    final w225 = displayToGrams(225, WeightUnit.lb);
    expect(_plan(w225, step: 5, unit: WeightUnit.lb, minWeight: 45), [
      (displayToGrams(90, WeightUnit.lb), 8),
      (displayToGrams(135, WeightUnit.lb), 5),
      (displayToGrams(180, WeightUnit.lb), 3),
    ]);
  });
}
