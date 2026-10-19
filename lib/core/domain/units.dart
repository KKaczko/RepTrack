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

/// Następna wielokrotność [step] powyżej ([direction] > 0) albo poniżej
/// [value], nie mniej niż zero. Wartość spoza siatki kroku trafia na
/// najbliższy punkt siatki w danym kierunku (81 → 82,5 albo 80 przy 2,5).
double stepValue(double value, double step, int direction) {
  if (step <= 0) return value;
  const epsilon = 1e-6;
  final k = value / step;
  final target = direction > 0
      ? (k + epsilon).floor() + 1
      : (k - epsilon).ceil() - 1;
  final result = roundToStep(target * step, step);
  return result < 0 ? 0 : result;
}
