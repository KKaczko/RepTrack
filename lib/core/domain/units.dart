import 'coded_enum.dart';

/// Jednostki wyświetlania ciężaru. Baza zawsze przechowuje gramy (ADR 0010).
enum WeightUnit implements CodedEnum {
  kg('kg'),
  lb('lb');

  const WeightUnit(this.code);

  @override
  final String code;
}

/// Gramy w jednym funcie (definicja międzynarodowa).
const double gramsPerPound = 453.59237;

/// Przelicza gramy z bazy na wartość w jednostce wyświetlania.
double gramsToDisplay(int grams, WeightUnit unit) => switch (unit) {
  WeightUnit.kg => grams / 1000,
  WeightUnit.lb => grams / gramsPerPound,
};

/// Przelicza wartość wpisaną w jednostce wyświetlania na gramy (zaokrąglone).
int displayToGrams(num value, WeightUnit unit) => switch (unit) {
  WeightUnit.kg => (value * 1000).round(),
  WeightUnit.lb => (value * gramsPerPound).round(),
};

/// Zaokrągla wartość wyświetlaną do najbliższej wielokrotności kroku.
double roundToStep(double value, double step) {
  if (step <= 0) return value;
  final steps = (value / step).round();
  // Unika artefaktów typu 82.50000000000001.
  return double.parse((steps * step).toStringAsFixed(3));
}
