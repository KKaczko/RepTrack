import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reptrack/core/domain/local_date.dart';
import 'package:reptrack/core/domain/units.dart';
import 'package:reptrack/core/l10n/generated/app_localizations.dart';
import 'package:reptrack/features/assistant/domain/assistant_context.dart';
import 'package:reptrack/features/assistant/presentation/assistant_context_labels.dart';

import '../../../support/workout_fixtures.dart';

final _oct12 = finishedPush('b', DateTime.utc(2026, 10, 12, 16), [
  (80000, 10),
  (80000, 9),
]);
final _oct19 = finishedPush('c', DateTime.utc(2026, 10, 19, 16), [
  (85000, 8),
  (85000, 7),
]);

/// Historia od najnowszego, jak w aplikacji.
final _history = [_oct19, _oct12];

AssistantFormat _format(String code, {WeightUnit unit = WeightUnit.kg}) => (
  labels: assistantContextLabels(lookupAppLocalizations(Locale(code)), unit),
  unit: unit,
  locale: code,
);

void main() {
  group('przegląd do rozmowy', () {
    final text = coachContext(
      history: _history,
      catalog: catalog,
      today: const LocalDate(2026, 10, 19),
      format: _format('pl'),
    );

    test('podsumowanie 4 tygodni z porównaniem', () {
      expect(
        text,
        contains('# Dane treningowe z RepTrack (stan na 2026-10-19)'),
      );
      expect(text, contains('Jednostka ciężaru: kg.'));
      expect(text, contains('- Treningi: 2 (poprzednio 0)'));
      expect(text, contains('- Serie: 4 (poprzednio 0)'));
    });

    test('serie na partię i pominięte partie', () {
      // 4 serie robocze ławki w 4 tygodnie: klatka 1, triceps i barki 0,5.
      expect(text, contains('- Klatka piersiowa: 1\n'));
      expect(text, contains('- Triceps: 0,5'));
      expect(text, contains('Partie bez serii roboczych w tym okresie:'));
      expect(text, contains('Łydki'));
    });

    test('postęp ćwiczeń z liczbami z domeny', () {
      // 80 kg × 10 → 85 kg × 8: szacowany 1RM 106,7 → 107,7 kg.
      expect(
        text,
        contains(
          '- Wyciskanie: Szacowany 1RM 107,7 kg; Zmiana w okresie +0,9%; '
          'Najlepsza seria 85 kg × 8; Treningi z ćwiczeniem: 2; '
          'ostatnio 2026-10-19',
        ),
      );
      // Podciąganie bez zatwierdzonych serii nie trafia do przeglądu.
      expect(text, isNot(contains('- Podciąganie:')));
    });

    test('ostatnie treningi jako tabele pod nagłówkiem kontekstu', () {
      expect(text, contains('## Ostatnie treningi'));
      expect(text, contains('### 2026-10-19 · Push A'));
      expect(text, contains('#### Wyciskanie'));
    });

    test('jednostki w funtach i teksty po angielsku', () {
      final english = coachContext(
        history: _history,
        catalog: catalog,
        today: const LocalDate(2026, 10, 19),
        format: _format('en', unit: WeightUnit.lb),
      );
      expect(english, contains('Weight unit: lb.'));
      expect(english, contains('- Workouts: 2 (previously 0)'));
      expect(english, contains('lb'));
      expect(english, isNot(contains(' kg')));
    });

    test('rozsądny rozmiar dla małego modelu', () {
      expect(text.length, lessThan(6000));
    });
  });

  test('komentarz do treningu: porównanie i rekordy', () {
    final text = sessionReviewContext(
      session: _oct19,
      history: _history,
      catalog: catalog,
      format: _format('pl'),
    );

    expect(text, contains('# Trening do omówienia'));
    expect(text, isNot(contains('Ostatnie treningi')));
    expect(text, contains('### Wyciskanie'));
    expect(
      text,
      contains(
        '- Wyciskanie: teraz: 85×8, 85×7; poprzednio (2026-10-12): '
        '80×10, 80×9; Szacowany 1RM 106,7 kg → 107,7 kg; Objętość',
      ),
    );
    expect(text, isNot(contains('- Podciąganie:')));
    expect(text, contains('## Rekordy pobite w tym treningu'));
    expect(text, contains('- Wyciskanie: Szacowany 1RM 107,7 kg'));
  });

  test('komentarz do pierwszego treningu: bez rekordów', () {
    final text = sessionReviewContext(
      session: _oct12,
      history: _history,
      catalog: catalog,
      format: _format('pl'),
    );

    expect(
      text,
      contains('- Wyciskanie: teraz: 80×10, 80×9; pierwsze wykonanie'),
    );
    expect(text, contains('Brak nowych rekordów.'));
  });

  test('propozycja treningu: plan szablonu i ostatnie wykonania', () {
    final text = nextWorkoutContext(
      template: pushTemplate(),
      history: _history,
      catalog: catalog,
      format: _format('pl'),
    );

    expect(text, contains('# Szablon: Push A'));
    expect(text, contains('## Wyciskanie'));
    expect(
      text,
      contains(
        'Plan: Rozgrzewkowa: 10 powt., 40 kg, przerwa 2:30; '
        'Robocza: 8–12 powt., 80 kg, przerwa 2:30;',
      ),
    );
    expect(text, contains('- 2026-10-19: 85×8, 85×7'));
    expect(text, contains('- 2026-10-12: 80×10, 80×9'));
    expect(text, contains('Szacowany 1RM: 107,7 kg'));
    expect(text, contains('## Podciąganie'));
    expect(text, contains('Pełny zwis'));
    expect(text, contains('Brak wcześniejszych wykonań.'));
  });
}
