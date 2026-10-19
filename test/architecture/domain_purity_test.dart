import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Warstwa domeny to czysty Dart: bez Fluttera, Drift i warstw data/presentation
/// (docs/architecture.md). Dzięki temu logika treningowa jest testowalna bez
/// emulatora, a przyszła synchronizacja nie zmienia logiki.
void main() {
  final forbidden = <RegExp, String>{
    RegExp(r'''import\s+['"]package:flutter/'''): 'Flutter',
    RegExp(r'''import\s+['"]dart:ui['"]'''): 'dart:ui',
    RegExp(r'''import\s+['"]package:drift'''): 'Drift',
    RegExp(r'''import\s+['"]package:flutter_riverpod'''): 'Riverpod',
    RegExp(
      r'''import\s+['"](\.\.?/|package:reptrack/)[^'"]*/(data|presentation)/''',
    ): 'data/presentation',
  };

  final domainFiles = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) {
        final path = f.path.replaceAll(r'\', '/');
        return path.contains('/domain/') &&
            path.endsWith('.dart') &&
            !path.endsWith('.g.dart') &&
            !path.endsWith('.freezed.dart');
      })
      .toList();

  test('istnieją pliki domeny do sprawdzenia', () {
    expect(domainFiles, isNotEmpty);
  });

  for (final file in domainFiles) {
    test('${file.path} nie importuje warstw zewnętrznych', () {
      final source = file.readAsStringSync();
      for (final MapEntry(key: pattern, value: name) in forbidden.entries) {
        expect(
          pattern.hasMatch(source),
          isFalse,
          reason: '${file.path} importuje $name',
        );
      }
    });
  }
}
