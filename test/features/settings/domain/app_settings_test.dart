import 'package:flutter_test/flutter_test.dart';
import 'package:reptrack/core/domain/units.dart';
import 'package:reptrack/features/exercises/domain/exercise.dart';
import 'package:reptrack/features/settings/domain/app_settings.dart';

void main() {
  test('zmiana jednostki zachowuje krok, który istnieje w nowej', () {
    const settings = AppSettings();
    final lb = withWeightUnit(settings, WeightUnit.lb);
    expect(lb.weightUnit, WeightUnit.lb);
    expect(lb.weightStep, 2.5);
  });

  test('krok spoza listy nowej jednostki wraca do domyślnego', () {
    const settings = AppSettings(weightStep: 1.25);
    expect(withWeightUnit(settings, WeightUnit.lb).weightStep, 5);
    const lb = AppSettings(weightUnit: WeightUnit.lb, weightStep: 10);
    expect(withWeightUnit(lb, WeightUnit.kg).weightStep, 2.5);
  });

  test('krok dla sprzętu: własny albo ogólny', () {
    const settings = AppSettings(
      equipmentWeightSteps: {Equipment.dumbbell: 2, Equipment.machine: 5},
    );

    expect(weightStepFor(Equipment.dumbbell, settings), 2);
    expect(weightStepFor(Equipment.machine, settings), 5);
    expect(weightStepFor(Equipment.barbell, settings), 2.5);
    expect(weightStepFor(null, settings), 2.5);
  });

  test('zmiana jednostki czyści kroki dla sprzętu', () {
    const settings = AppSettings(equipmentWeightSteps: {Equipment.dumbbell: 2});

    expect(
      withWeightUnit(settings, WeightUnit.lb).equipmentWeightSteps,
      isEmpty,
    );
  });
}
