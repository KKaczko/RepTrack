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
String formatWeight(
  int grams,
  WeightUnit unit,
  String locale, {
  int maxDecimals = 2,
}) =>
    '${formatWeightValue(grams, unit, locale, maxDecimals: maxDecimals)} '
    '${weightUnitLabel(unit)}';

/// Sama wartość ciężaru w jednostce wyświetlania, np. „82,5”.
String formatWeightValue(
  int grams,
  WeightUnit unit,
  String locale, {
  int maxDecimals = 2,
}) => formatDecimal(
  gramsToDisplay(grams, unit),
  locale,
  maxDecimals: maxDecimals,
);

/// Szacowany 1RM z jednym miejscem po przecinku, np. „106,7 kg”.
String formatEstimate(double grams, WeightUnit unit, String locale) =>
    formatWeight(grams.round(), unit, locale, maxDecimals: 1);

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

/// Czas wpisany jako „m:ss” (np. „1:45”) albo w sekundach („105”). Null
/// dla tekstu, który nie jest czasem.
int? parseClock(String input) {
  final text = input.trim();
  if (text.isEmpty) return null;
  final parts = text.split(':');
  if (parts.length > 2) return null;
  final numbers = [for (final p in parts) int.tryParse(p.trim())];
  if (numbers.any((n) => n == null || n < 0)) return null;
  if (numbers.length == 1) return numbers.single;
  final [minutes, seconds] = numbers.nonNulls.toList();
  if (seconds > 59) return null;
  return minutes * 60 + seconds;
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

/// Wartości serii, np. „80×10”, „10”, „1:30”, „30:00 · 5000 m”. Ciężar
/// bez jednostki (jest w nagłówku), puste pola są pomijane. Null, gdy seria
/// nie ma żadnej wartości.
String? formatSetValues({
  required WeightUnit unit,
  required String locale,
  int? weightG,
  int? reps,
  int? durationS,
  int? distanceM,
  String metersUnit = 'm',
}) {
  final load = [
    if (weightG != null) formatWeightValue(weightG, unit, locale),
    if (reps != null) '$reps',
  ].join('×');
  final parts = [
    if (load.isNotEmpty) load,
    if (durationS != null) formatClock(durationS),
    if (distanceM != null) '$distanceM $metersUnit',
  ];
  return parts.isEmpty ? null : parts.join(' · ');
}

/// Objętość, np. „4520 kg” (bez miejsc po przecinku).
String formatVolume(int grams, WeightUnit unit, String locale) =>
    '${formatDecimal(gramsToDisplay(grams, unit), locale, maxDecimals: 0)} '
    '${weightUnitLabel(unit)}';
