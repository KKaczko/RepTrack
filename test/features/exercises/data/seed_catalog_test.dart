import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:reptrack/core/domain/text_normalize.dart';
import 'package:reptrack/features/exercises/data/seed_catalog.dart';
import 'package:reptrack/features/exercises/domain/exercise.dart';

final _uuidV7 = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-7[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
);

/// Sprawdza wygenerowany plik `assets/seed/exercises.json` (ADR 0005).
void main() {
  final raw = File(seedAssetPath).readAsStringSync();
  final catalog = parseSeedCatalog(raw);
  final exercises = catalog.exercises;

  test('katalog ma 100–150 ćwiczeń', () {
    expect(exercises.length, inInclusiveRange(100, 150));
    expect(catalog.seedVersion, greaterThanOrEqualTo(1));
  });

  test('identyfikatory to unikalne UUIDv7 zgodne z tool/seed/ids.json', () {
    final ids = [for (final e in exercises) e.id];
    expect(ids.toSet(), hasLength(ids.length));
    expect(ids.every(_uuidV7.hasMatch), isTrue);

    final keys =
        (jsonDecode(raw) as Map<String, dynamic>)['exercises'] as List<dynamic>;
    final idsJson = (jsonDecode(
      File('tool/seed/ids.json').readAsStringSync(),
    ) as Map<String, dynamic>).cast<String, String>();
    for (final entry in keys.cast<Map<String, dynamic>>()) {
      expect(idsJson[entry['key']], entry['id'], reason: '${entry['key']}');
    }
  });

  test('nazwy są unikalne także bez polskich znaków', () {
    final names = [for (final e in exercises) normalizeForSearch(e.name)];
    expect(names.toSet(), hasLength(names.length));
  });

  for (final exercise in exercises) {
    test('poprawna pozycja: ${exercise.name}', () {
      expect(exercise.source, ExerciseSource.builtin);
      expect(exercise.userModified, isFalse);
      expect(exercise.seedVersion, isNotNull);
      expect(exercise.measurement.isValid, isTrue);
      expect(exercise.aliases, isNotEmpty);
      expect(exercise.primaryMuscles, isNotEmpty);
      expect(
        exercise.secondaryMuscles.toSet().intersection(
          exercise.primaryMuscles.toSet(),
        ),
        isEmpty,
      );
      final cues = exercise.instructions!.split('\n');
      expect(cues.length, inInclusiveRange(2, 4));
      expect(exercise.originRef, isNotNull);
      expect(exercise.licenseAuthor, isNotNull);
      if (exercise.originRef!.startsWith('free-exercise-db:')) {
        expect(exercise.license, 'Unlicense');
      } else {
        expect(exercise.originRef, startsWith('reptrack:'));
      }
      if (exercise.loadMode == LoadMode.assisted ||
          exercise.loadMode == LoadMode.weightedBodyweight) {
        expect(exercise.measurement.weight, isTrue);
      }
    });
  }

  test('odrzuca nieobsługiwaną wersję formatu', () {
    expect(
      () => parseSeedCatalog('{"formatVersion": 2, "seedVersion": 1}'),
      throwsFormatException,
    );
  });
}
