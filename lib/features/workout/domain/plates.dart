/// Kalkulator talerzy (ADR 0020). Wartości w jednostce wyświetlania
/// (kg albo lb), bo talerze mają nominały w tej jednostce.
library;

/// Talerze na jedną stronę gryfu i ciężar, którego nie da się złożyć
/// (łącznie na obie strony).
typedef PlateLoad = ({List<double> perSide, double remainder});

/// Talerze na stronę dla ciężaru [total] na gryfie [bar], zachłannie od
/// największego z [plates] (bez limitu sztuk). Null, gdy [total] jest
/// mniejszy niż sam gryf.
PlateLoad? platesPerSide(double total, double bar, List<double> plates) {
  const epsilon = 1e-6;
  if (total + epsilon < bar) return null;
  var side = (total - bar) / 2;
  final perSide = <double>[];
  for (final plate in [...plates]..sort((a, b) => b.compareTo(a))) {
    if (plate <= 0) continue;
    while (side + epsilon >= plate) {
      perSide.add(plate);
      side -= plate;
    }
  }
  final remainder = double.parse((side * 2).toStringAsFixed(3));
  return (perSide: perSide, remainder: remainder < epsilon ? 0 : remainder);
}
