import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:reptrack/core/domain/local_date.dart';
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

  test('wartości serii i objętość', () {
    expect(
      formatSetValues(
        unit: WeightUnit.kg,
        locale: 'pl',
        weightG: 82500,
        reps: 8,
      ),
      '82,5×8',
    );
    expect(formatSetValues(unit: WeightUnit.kg, locale: 'pl', reps: 12), '12');
    expect(
      formatSetValues(
        unit: WeightUnit.kg,
        locale: 'pl',
        durationS: 1800,
        distanceM: 5000,
      ),
      '30:00 · 5000 m',
    );
    expect(formatSetValues(unit: WeightUnit.kg, locale: 'pl'), isNull);
    // Polski format grupuje tysiące twardą spacją.
    expect(
      formatVolume(4520000, WeightUnit.kg, 'pl').replaceAll(' ', ' '),
      '4 520 kg',
    );
  });

  test('godzina startu w strefie sesji', () {
    // 16:05 UTC to 18:05 w Warszawie (czas letni).
    expect(localTimeFor(DateTime.utc(2026, 10, 19, 16, 5), 'Europe/Warsaw'), (
      hour: 18,
      minute: 5,
    ));
  });

  test('parseClock: m:ss albo sekundy', () {
    expect(parseClock('1:45'), 105);
    expect(parseClock(' 105 '), 105);
    expect(parseClock('0:05'), 5);
    expect(parseClock('15:00'), 900);
    expect(parseClock('1:60'), isNull);
    expect(parseClock('1:2:3'), isNull);
    expect(parseClock('abc'), isNull);
    expect(parseClock('-5'), isNull);
    expect(parseClock(''), isNull);
  });
}
