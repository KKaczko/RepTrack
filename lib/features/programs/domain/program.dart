import 'dart:convert';

import '../../../core/domain/training.dart';

/// Gotowe programy treningowe (ADR 0019): kilka szablonów i plan tygodnia
/// do dodania jednym przyciskiem. Treść jest własna RepTrack, w pliku
/// `assets/programs/programs.json`.

/// Ścieżka biblioteki programów w zasobach aplikacji.
const programsAssetPath = 'assets/programs/programs.json';

/// Wersja formatu pliku programów obsługiwana przez aplikację.
const supportedProgramsFormatVersion = 1;

enum ProgramLevel { beginner, intermediate }

enum ProgramEquipment { gym, dumbbells, bodyweight }

/// Tekst w językach aplikacji; brakujący język zastępuje polski.
final class LocalizedText {
  const LocalizedText({required this.pl, required this.en});

  final String pl;
  final String en;

  String of(String languageCode) => languageCode == 'en' ? en : pl;
}

/// Ćwiczenie programu: klucz ćwiczenia wbudowanego (seed), liczba serii,
/// cel (powtórzenia albo sekundy), przerwa i opcjonalny znacznik superserii
/// (kolejne ćwiczenia z tym samym znacznikiem tworzą superserię).
final class ProgramExercise {
  const ProgramExercise({
    required this.exerciseKey,
    required this.sets,
    required this.targetKind,
    required this.targetMin,
    required this.targetMax,
    required this.restSeconds,
    this.superset,
  });

  final String exerciseKey;
  final int sets;
  final TargetKind targetKind;
  final int targetMin;
  final int targetMax;
  final int restSeconds;
  final String? superset;
}

final class ProgramWorkout {
  const ProgramWorkout({
    required this.key,
    required this.name,
    required this.exercises,
  });

  final String key;
  final LocalizedText name;
  final List<ProgramExercise> exercises;
}

final class Program {
  const Program({
    required this.id,
    required this.name,
    required this.description,
    required this.level,
    required this.equipment,
    required this.schedule,
    required this.workouts,
  });

  final String id;
  final LocalizedText name;
  final LocalizedText description;
  final ProgramLevel level;
  final ProgramEquipment equipment;

  /// Dzień tygodnia (1 = poniedziałek) → klucz treningu.
  final Map<int, String> schedule;
  final List<ProgramWorkout> workouts;

  int get daysPerWeek => schedule.length;

  ProgramWorkout? workout(String key) {
    for (final w in workouts) {
      if (w.key == key) return w;
    }
    return null;
  }
}

/// Parsuje bibliotekę programów. Rzuca [FormatException] dla
/// nieobsługiwanego formatu albo niepoprawnych danych.
List<Program> parsePrograms(String source) {
  final json = jsonDecode(source);
  if (json is! Map<String, Object?> ||
      json['formatVersion'] != supportedProgramsFormatVersion) {
    throw const FormatException('Nieobsługiwany format pliku programów');
  }
  try {
    return [
      for (final raw in json['programs']! as List<Object?>)
        _program(raw! as Map<String, Object?>),
    ];
  } on TypeError catch (error) {
    throw FormatException('Niepoprawny plik programów: $error');
  }
}

Program _program(Map<String, Object?> json) => Program(
  id: json['id']! as String,
  name: _text(json['name']),
  description: _text(json['description']),
  level: ProgramLevel.values.byName(json['level']! as String),
  equipment: ProgramEquipment.values.byName(json['equipment']! as String),
  schedule: {
    for (final MapEntry(:key, :value)
        in (json['schedule']! as Map<String, Object?>).entries)
      int.parse(key): value! as String,
  },
  workouts: [
    for (final raw in json['workouts']! as List<Object?>)
      _workout(raw! as Map<String, Object?>),
  ],
);

ProgramWorkout _workout(Map<String, Object?> json) => ProgramWorkout(
  key: json['key']! as String,
  name: _text(json['name']),
  exercises: [
    for (final raw in json['exercises']! as List<Object?>)
      _exercise(raw! as Map<String, Object?>),
  ],
);

ProgramExercise _exercise(Map<String, Object?> json) {
  final reps = json['reps'] as List<Object?>?;
  final seconds = json['seconds'] as List<Object?>?;
  final range = (reps ?? seconds)!;
  return ProgramExercise(
    exerciseKey: json['exercise']! as String,
    sets: json['sets']! as int,
    targetKind: reps != null ? TargetKind.reps : TargetKind.duration,
    targetMin: range[0]! as int,
    targetMax: range[1]! as int,
    restSeconds: json['rest']! as int,
    superset: json['superset'] as String?,
  );
}

LocalizedText _text(Object? json) {
  final map = json! as Map<String, Object?>;
  return LocalizedText(pl: map['pl']! as String, en: map['en']! as String);
}
