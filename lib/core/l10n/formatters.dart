import 'package:intl/intl.dart';

import '../domain/training.dart';
import '../domain/units.dart';

/// Formatowanie i parsowanie wartości w UI. Baza przechowuje gramy i sekundy,
/// konwersja na jednostki wyświetlania odbywa się wyłącznie tutaj (ADR 0010).

/// Liczba z co najwyżej [maxDecimals] miejscami po przecinku, bez zbędnych
/// zer, w formacie języka [locale] (np. „82,5” po polsku).
String formatDecimal(num value, String locale, {int maxDecimals = 2}) {
  final format = NumberFormat.decimalPattern(locale)
    ..minimumFractionDigits = 0
    ..maximumFractionDigits = maxDecimals;
  return format.format(value);
}

String weightUnitLabel(WeightUnit unit) => switch (unit) {
  WeightUnit.kg => 'kg',
  WeightUnit.lb => 'lb',
};

/// Ciężar z jednostką, np. „82,5 kg”.
String formatWeight(int grams, WeightUnit unit, String locale) =>
    '${formatWeightValue(grams, unit, locale)} ${weightUnitLabel(unit)}';

/// Sama wartość ciężaru w jednostce wyświetlania, np. „82,5”.
String formatWeightValue(int grams, WeightUnit unit, String locale) =>
    formatDecimal(gramsToDisplay(grams, unit), locale);

/// Parsuje ciężar wpisany w jednostce wyświetlania. Akceptuje przecinek
/// i kropkę dziesiętną. Zwraca null dla pustego, niepoprawnego albo
/// ujemnego wpisu.
int? parseWeight(String input, WeightUnit unit) {
  final value = parseDecimal(input);
  if (value == null || value < 0) return null;
  return displayToGrams(value, unit);
}

/// Parsuje liczbę z przecinkiem albo kropką dziesiętną.
double? parseDecimal(String input) {
  final normalized = input.trim().replaceAll(' ', '').replaceAll(',', '.');
  if (normalized.isEmpty) return null;
  return double.tryParse(normalized);
}

/// Parsuje nieujemną liczbę całkowitą (powtórzenia, sekundy).
int? parseCount(String input) {
  final value = int.tryParse(input.trim());
  return value == null || value < 0 ? null : value;
}

/// Czas w formacie zegara, np. „1:30”, „12:05”, „1:02:03”.
String formatClock(int seconds) {
  final h = seconds ~/ 3600;
  final m = (seconds % 3600) ~/ 60;
  final s = seconds % 60;
  final ss = s.toString().padLeft(2, '0');
  if (h > 0) return '$h:${m.toString().padLeft(2, '0')}:$ss';
  return '$m:$ss';
}

/// Zakres celu serii, np. „8–12”, „10”, „30–60 s”. Pusty, gdy brak celu.
String formatTarget(TargetKind kind, int? min, int? max) {
  final String range;
  if (min == null && max == null) {
    return '';
  } else if (min == null || max == null || min == max) {
    range = '${min ?? max}';
  } else {
    range = '$min–$max';
  }
  return kind == TargetKind.duration ? '$range s' : range;
}
