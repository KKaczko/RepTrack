import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// Granice między funkcjami (docs/architecture.md): funkcja może używać
/// cudzej domeny, publicznych providerów (`data/*_providers.dart`)
/// i etykiet (`presentation/*_labels.dart`), ale nie
/// implementacji repozytoriów ani ekranów innej funkcji. Ekrany innych funkcji
/// otwiera się przez trasy routera (`lib/app/`).
void main() {
  final importPattern = RegExp(
    r'''^import\s+['"]([^'"]+)['"]''',
    multiLine: true,
  );

  String? featureOf(String normalizedPath) {
    final parts = p.posix.split(normalizedPath);
    final index = parts.indexOf('features');
    return index >= 0 && index + 1 < parts.length ? parts[index + 1] : null;
  }

  final files = Directory('lib/features')
      .listSync(recursive: true)
      .whereType<File>()
      .where(
        (f) =>
            f.path.endsWith('.dart') &&
            !f.path.endsWith('.g.dart') &&
            !f.path.endsWith('.freezed.dart'),
      )
      .toList();

  for (final file in files) {
    final path = p.posix.normalize(file.path.replaceAll(r'\', '/'));
    final ownFeature = featureOf(path);
    test('$path respektuje granice funkcji', () {
      for (final match in importPattern.allMatches(file.readAsStringSync())) {
        final uri = match.group(1)!;
        final String target;
        if (uri.startsWith('package:reptrack/')) {
          target = 'lib/${uri.substring('package:reptrack/'.length)}';
        } else if (!uri.contains(':')) {
          target = p.posix.normalize(p.posix.join(p.posix.dirname(path), uri));
        } else {
          continue;
        }
        final otherFeature = featureOf(target);
        if (otherFeature == null || otherFeature == ownFeature) continue;
        final layer = p.posix.split(target)[3];
        final allowed =
            layer == 'domain' ||
            (layer == 'data' && target.endsWith('_providers.dart')) ||
            // Etykiety (mapowanie wartości na teksty), bez ekranów.
            (layer == 'presentation' && target.endsWith('_labels.dart'));
        expect(allowed, isTrue, reason: '$path importuje $target');
      }
    });
  }
}
