import 'dart:convert';

import '../../../core/domain/coded_enum.dart';
import '../domain/exercise.dart';

/// Ścieżka wbudowanej biblioteki w zasobach aplikacji.
const seedAssetPath = 'assets/seed/exercises.json';

/// Wersja formatu pliku seed obsługiwana przez aplikację.
const supportedSeedFormatVersion = 1;

/// Wbudowana biblioteka ćwiczeń wczytana z `assets/seed/exercises.json`,
/// generowanego przez `tool/seed/build_seed.dart`.
final class SeedCatalog {
  const SeedCatalog({required this.seedVersion, required this.exercises});

  /// Wersja całego pliku; aplikacja synchronizuje bazę, gdy jest nowsza od
  /// ostatnio zastosowanej.
  final int seedVersion;

  /// Ćwiczenia z `seedVersion` równym rewizji pozycji.
  final List<Exercise> exercises;
}

/// Parsuje plik seed. Rzuca [FormatException] dla nieobsługiwanego formatu
/// albo niepoprawnych danych.
SeedCatalog parseSeedCatalog(String source) {
  final json = jsonDecode(source) as Map<String, dynamic>;
  final format = json['formatVersion'];
  if (format != supportedSeedFormatVersion) {
    throw FormatException('Nieobsługiwana wersja formatu seeda', format);
  }
  return SeedCatalog(
    seedVersion: json['seedVersion'] as int,
    exercises: [
      for (final raw in json['exercises'] as List<dynamic>)
        _exercise(raw as Map<String, dynamic>),
    ],
  );
}

Exercise _exercise(Map<String, dynamic> json) {
  final measurement = json['measurement'] as Map<String, dynamic>;
  T? optional<T extends CodedEnum>(List<T> values, String field) {
    final raw = json[field] as String?;
    return raw == null ? null : enumFromCode(values, raw);
  }

  List<MuscleGroup> muscles(String field) => [
    for (final code in (json[field] as List<dynamic>).cast<String>())
      enumFromCode(MuscleGroup.values, code),
  ];

  return Exercise(
    id: json['id'] as String,
    name: json['name'] as String,
    aliases: (json['aliases'] as List<dynamic>).cast<String>(),
    primaryMuscles: muscles('primaryMuscles'),
    secondaryMuscles: muscles('secondaryMuscles'),
    equipment: optional(Equipment.values, 'equipment'),
    category: enumFromCode(ExerciseCategory.values, json['category'] as String),
    mechanic: optional(Mechanic.values, 'mechanic'),
    force: optional(Force.values, 'force'),
    instructions: json['instructions'] as String?,
    measurement: Measurement(
      weight: measurement['weight'] as bool,
      reps: measurement['reps'] as bool,
      duration: measurement['duration'] as bool,
      distance: measurement['distance'] as bool,
    ),
    loadMode: enumFromCode(LoadMode.values, json['loadMode'] as String),
    weightSemantics: enumFromCode(
      WeightSemantics.values,
      json['weightSemantics'] as String,
    ),
    isUnilateral: json['isUnilateral'] as bool,
    source: ExerciseSource.builtin,
    originRef: json['originRef'] as String?,
    license: json['license'] as String?,
    licenseAuthor: json['licenseAuthor'] as String?,
    seedVersion: json['rev'] as int,
  );
}
