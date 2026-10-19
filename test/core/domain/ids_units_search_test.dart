import 'package:flutter_test/flutter_test.dart';
import 'package:reptrack/core/domain/ids.dart';
import 'package:reptrack/core/domain/text_normalize.dart';
import 'package:reptrack/core/domain/units.dart';

final _uuidV7 = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-7[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
);

void main() {
  group('UuidV7Generator', () {
    test('generuje UUIDv7 w postaci tekstowej', () {
      const ids = UuidV7Generator();

      expect(ids.newId(), matches(_uuidV7));
    });

    test('identyfikatory są unikalne i rosną z czasem', () async {
      const ids = UuidV7Generator();
      final first = ids.newId();
      await Future<void>.delayed(const Duration(milliseconds: 2));
      final second = ids.newId();

      expect(first, isNot(second));
      expect(second.compareTo(first), greaterThan(0));
    });
  });

  group('jednostki ciężaru', () {
    test('kg ↔ gramy', () {
      expect(displayToGrams(82.5, WeightUnit.kg), 82500);
      expect(gramsToDisplay(82500, WeightUnit.kg), 82.5);
    });

    test('lb ↔ gramy bez dryfu po zaokrągleniu', () {
      final grams = displayToGrams(135, WeightUnit.lb);

      expect(grams, 61235);
      expect(gramsToDisplay(grams, WeightUnit.lb), closeTo(135, 0.001));
    });

    test('zaokrąglanie do kroku', () {
      expect(roundToStep(81.3, 2.5), 82.5);
      expect(roundToStep(80.1, 2.5), 80.0);
      expect(roundToStep(0.1 + 0.2, 0.1), 0.3);
    });

    test('stepValue idzie do następnego punktu siatki kroku', () {
      expect(stepValue(80, 2.5, 1), 82.5);
      expect(stepValue(80, 2.5, -1), 77.5);
      // Wartość spoza siatki trafia na najbliższy punkt w danym kierunku.
      expect(stepValue(81, 2.5, 1), 82.5);
      expect(stepValue(81, 2.5, -1), 80);
      expect(stepValue(0, 2.5, -1), 0);
      expect(stepValue(1, 2.5, -1), 0);
      expect(stepValue(20, 1.25, 1), 21.25);
    });
  });

  group('normalizeForSearch', () {
    test('usuwa polskie znaki i wielkie litery', () {
      expect(
        normalizeForSearch('Wyciskanie na ŁAWCE skośnej'),
        'wyciskanie na lawce skosnej',
      );
      expect(normalizeForSearch('Żuraw, źdźbło'), 'zuraw zdzblo');
    });

    test(
      '„lawka” znajduje „ławka”, także po aliasie i w dowolnej kolejności',
      () {
        final haystack = normalizeForSearch('Ławka płaska; bench press');

        expect(matchesSearch(haystack, 'lawka'), isTrue);
        expect(matchesSearch(haystack, 'PRESS bench'), isTrue);
        expect(matchesSearch(haystack, 'przysiad'), isFalse);
        expect(matchesSearch(haystack, '  '), isTrue);
      },
    );
  });
}
