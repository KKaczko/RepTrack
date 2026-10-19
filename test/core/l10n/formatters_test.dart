import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:reptrack/core/domain/training.dart';
import 'package:reptrack/core/domain/units.dart';
import 'package:reptrack/core/l10n/formatters.dart';

void main() {
  setUpAll(() => initializeDateFormatting('pl'));

  group('ciężar', () {
    test('polski przecinek dziesiętny i bez zbędnych zer', () {
      expect(formatWeight(82500, WeightUnit.kg, 'pl'), '82,5 kg');
      expect(formatWeight(80000, WeightUnit.kg, 'pl'), '80 kg');
      expect(formatWeight(1250, WeightUnit.kg, 'pl'), '1,25 kg');
      expect(formatWeight(82500, WeightUnit.kg, 'en'), '82.5 kg');
    });

    test('funty', () {
      expect(formatWeight(61235, WeightUnit.lb, 'en'), '135 lb');
    });

    test('parsowanie przecinka, kropki i błędnych wpisów', () {
      expect(parseWeight('82,5', WeightUnit.kg), 82500);
      expect(parseWeight(' 82.5 ', WeightUnit.kg), 82500);
      expect(parseWeight('135', WeightUnit.lb), 61235);
      expect(parseWeight('', WeightUnit.kg), isNull);
      expect(parseWeight('abc', WeightUnit.kg), isNull);
      expect(parseWeight('-5', WeightUnit.kg), isNull);
    });
  });

  test('liczby całkowite', () {
    expect(parseCount('12'), 12);
    expect(parseCount(' 0 '), 0);
    expect(parseCount('-1'), isNull);
    expect(parseCount('1,5'), isNull);
  });

  test('zegar', () {
    expect(formatClock(0), '0:00');
    expect(formatClock(90), '1:30');
    expect(formatClock(725), '12:05');
    expect(formatClock(3723), '1:02:03');
  });

  test('cel serii', () {
    expect(formatTarget(TargetKind.reps, 8, 12), '8–12');
    expect(formatTarget(TargetKind.reps, 10, 10), '10');
    expect(formatTarget(TargetKind.reps, null, 12), '12');
    expect(formatTarget(TargetKind.duration, 30, 60), '30–60 s');
    expect(formatTarget(TargetKind.reps, null, null), '');
  });
}
