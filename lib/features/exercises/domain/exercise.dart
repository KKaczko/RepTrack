import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../core/domain/text_normalize.dart';

part 'exercise.freezed.dart';

// Nazwy wartości enumów są stabilnymi kodami w bazie i backupie (ADR 0005).

enum MuscleGroup {
  abdominals,
  abductors,
  adductors,
  biceps,
  calves,
  chest,
  forearms,
  glutes,
  hamstrings,
  lats,
  lowerBack,
  middleBack,
  neck,
  quadriceps,
  shoulders,
  traps,
  triceps,
}

enum Equipment {
  barbell,
  dumbbell,
  kettlebell,
  cable,
  machine,
  smithMachine,
  ezBar,
  bodyweight,
  bands,
  medicineBall,
  exerciseBall,
  foamRoll,
  other,
}

enum ExerciseCategory {
  strength,
  cardio,
  mobility,
  plyometrics,
  olympic,
  strongman,
}

enum Mechanic { compound, isolation }

enum Force { push, pull, static }

/// Tryb obciążenia: zewnętrzne, masa ciała, masa ciała z dociążeniem, wspomaganie.
enum LoadMode { external, bodyweight, weightedBodyweight, assisted }

/// Co oznacza wpisany ciężar: łącznie, na rękę albo na stronę.
enum WeightSemantics { total, perHand, perSide }

enum ExerciseSource { builtin, user }

/// Pola mierzone w serii. Ćwiczenie deklaruje zestaw pól zamiast jednego typu,
/// np. spacer farmera to ciężar + dystans.
@freezed
abstract class Measurement with _$Measurement {
  const factory Measurement({
    @Default(false) bool weight,
    @Default(false) bool reps,
    @Default(false) bool duration,
    @Default(false) bool distance,
  }) = _Measurement;

  const Measurement._();

  static const weightAndReps = Measurement(weight: true, reps: true);
  static const repsOnly = Measurement(reps: true);
  static const durationOnly = Measurement(duration: true);

  /// Co najmniej jedno pole musi być mierzone.
  bool get isValid => weight || reps || duration || distance;
}

@freezed
abstract class Exercise with _$Exercise {
  const factory Exercise({
    required String id,
    required String name,
    @Default(<String>[]) List<String> aliases,
    @Default(<MuscleGroup>[]) List<MuscleGroup> primaryMuscles,
    @Default(<MuscleGroup>[]) List<MuscleGroup> secondaryMuscles,
    Equipment? equipment,
    @Default(ExerciseCategory.strength) ExerciseCategory category,
    Mechanic? mechanic,
    Force? force,
    String? instructions,
    @Default(Measurement.weightAndReps) Measurement measurement,
    @Default(LoadMode.external) LoadMode loadMode,
    @Default(WeightSemantics.total) WeightSemantics weightSemantics,
    @Default(false) bool isUnilateral,
    String? imageRef,
    @Default(ExerciseSource.user) ExerciseSource source,
    String? originRef,
    String? license,
    String? licenseAuthor,
    int? seedVersion,
    @Default(false) bool userModified,
    DateTime? archivedAt,
  }) = _Exercise;

  const Exercise._();

  bool get isArchived => archivedAt != null;

  bool get isBuiltin => source == ExerciseSource.builtin;

  /// Znormalizowany tekst do wyszukiwania po nazwie i aliasach.
  String get searchText => normalizeForSearch([name, ...aliases].join(' '));
}
