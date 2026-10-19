import 'package:flutter_test/flutter_test.dart';
import 'package:reptrack/core/domain/local_date.dart';

void main() {
  setUpAll(ensureTimeZonesLoaded);

  group('localDateFor', () {
    test('trening po północy należy do dnia rozpoczęcia', () {
      // Start 23:30 czasu warszawskiego (CEST, UTC+2) 18.10.2026.
      final start = DateTime.utc(2026, 10, 18, 21, 30);
      final end = start.add(const Duration(hours: 1, minutes: 30));

      expect(
        localDateFor(start, 'Europe/Warsaw'),
        const LocalDate(2026, 10, 18),
      );
      expect(localDateFor(end, 'Europe/Warsaw'), const LocalDate(2026, 10, 19));
    });

    test('ten sam moment ma różne daty w różnych strefach', () {
      final moment = DateTime.utc(2026, 10, 18, 23, 30);

      expect(
        localDateFor(moment, 'Europe/London'),
        const LocalDate(2026, 10, 19),
      );
      expect(
        localDateFor(moment, 'America/New_York'),
        const LocalDate(2026, 10, 18),
      );
      expect(localDateFor(moment, 'Asia/Tokyo'), const LocalDate(2026, 10, 19));
    });

    test('zmiana czasu na zimowy w Europe/Warsaw', () {
      // 25.10.2026 o 03:00 CEST zegar cofa się na 02:00 CET.
      final beforeShift = DateTime.utc(2026, 10, 24, 22, 30); // 00:30 CEST
      final afterShift = DateTime.utc(2026, 10, 25, 22, 30); // 23:30 CET

      expect(
        localDateFor(beforeShift, 'Europe/Warsaw'),
        const LocalDate(2026, 10, 25),
      );
      expect(
        localDateFor(afterShift, 'Europe/Warsaw'),
        const LocalDate(2026, 10, 25),
      );
    });

    test('przyjmuje także DateTime w czasie lokalnym', () {
      final utc = DateTime.utc(2026, 1, 1, 12);

      expect(
        localDateFor(utc.toLocal(), 'Europe/Warsaw'),
        localDateFor(utc, 'Europe/Warsaw'),
      );
    });

    test('rozpoznaje znane strefy', () {
      expect(isKnownTimeZone('Europe/Warsaw'), isTrue);
      expect(isKnownTimeZone('Mars/Olympus'), isFalse);
    });
  });

  group('LocalDate', () {
    test('ISO w obie strony', () {
      const date = LocalDate(2026, 3, 7);

      expect(date.toIso(), '2026-03-07');
      expect(LocalDate.parse('2026-03-07'), date);
    });

    test('odrzuca niepoprawne daty', () {
      expect(() => LocalDate.parse('2026-02-30'), throwsFormatException);
      expect(() => LocalDate.parse('2026-2-3'), throwsFormatException);
    });

    test('tydzień zaczyna się w poniedziałek', () {
      // 18.10.2026 to niedziela.
      expect(const LocalDate(2026, 10, 18).weekday, DateTime.sunday);
      expect(
        const LocalDate(2026, 10, 18).startOfWeek,
        const LocalDate(2026, 10, 12),
      );
      expect(
        const LocalDate(2026, 10, 19).startOfWeek,
        const LocalDate(2026, 10, 19),
      );
    });

    test('porównywanie i dodawanie dni przez koniec miesiąca', () {
      expect(
        const LocalDate(2026, 10, 31).addDays(1),
        const LocalDate(2026, 11, 1),
      );
      expect(
        const LocalDate(2026, 1, 1).compareTo(const LocalDate(2025, 12, 31)),
        greaterThan(0),
      );
    });
  });
}
