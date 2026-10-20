import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reptrack/core/domain/glossary.dart';
import 'package:reptrack/core/l10n/generated/app_localizations.dart';
import 'package:reptrack/core/l10n/glossary_labels.dart';

void main() {
  for (final code in ['pl', 'en']) {
    test('słowniczek $code: każde pojęcie ma tytuł i opis', () {
      final l10n = lookupAppLocalizations(Locale(code));
      final titles = {
        for (final term in GlossaryTerm.values) l10n.glossaryTermTitle(term),
      };
      expect(titles, hasLength(GlossaryTerm.values.length));
      for (final term in GlossaryTerm.values) {
        expect(l10n.glossaryTermBody(term).length, greaterThan(40));
      }
      for (final group in GlossaryGroup.values) {
        expect(l10n.glossaryGroup(group), isNotEmpty);
        expect(GlossaryTerm.values.where((t) => t.group == group), isNotEmpty);
      }
    });
  }

  test('wzór z opisu szacowanego 1RM zgadza się z przykładem', () {
    // 80 kg × 8 według Epleya: 80 × (1 + 8 / 30) ≈ 101 kg.
    expect(80 * (1 + 8 / 30), closeTo(101.3, 0.1));
    final l10n = lookupAppLocalizations(const Locale('pl'));
    expect(
      l10n.glossaryTermBody(GlossaryTerm.estimatedOneRepMax),
      contains('80 kg × 8 to około 101 kg'),
    );
  });
}
