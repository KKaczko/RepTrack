import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../core/domain/coded_enum.dart';
import '../../../core/domain/text_normalize.dart';

part 'exercise.freezed.dart';

// Kody (`code`) są zapisywane w bazie i backupie, więc nie wolno ich zmieniać
// (ADR 0013). Nazwy wartości w Dart można zmieniać swobodnie.

enum MuscleGroup implements CodedEnum {
  abdominals('abdominals'),
  abductors('abductors'),
  adductors('adductors'),
  biceps('biceps'),
  calves('calves'),
  chest('chest'),
  forearms('forearms'),
  glutes('glutes'),
  hamstrings('hamstrings'),
  lats('lats'),
  lowerBack('lower_back'),
  middleBack('middle_back'),
  neck('neck'),
  quadriceps('quadriceps'),
  shoulders('shoulders'),
  traps('traps'),
  triceps('triceps');

  const MuscleGroup(this.code);

  @override
  final String code;
}

enum Equipment implements CodedEnum {
  barbell('barbell'),
  dumbbell('dumbbell'),
  kettlebell('kettlebell'),
  cable('cable'),
  machine('machine'),
  smithMachine('smith_machine'),
  ezBar('ez_bar'),
  bodyweight('bodyweight'),
  bands('bands'),
  medicineBall('medicine_ball'),
  exerciseBall('exercise_ball'),
  foamRoll('foam_roll'),
  other('other');

  const Equipment(this.code);

  @override
  final String code;
}

enum ExerciseCategory implements CodedEnum {
  strength('strength'),
  cardio('cardio'),
  mobility('mobility'),
  plyometrics('plyometrics'),
  olympic('olympic'),
  strongman('strongman');

  const ExerciseCategory(this.code);

  @override
  final String code;
}

enum Mechanic implements CodedEnum {
  compound('compound'),
  isolation('isolation');

  const Mechanic(this.code);

  @override
  final String code;
}

enum Force implements CodedEnum {
  push('push'),
  pull('pull'),
  static('static');

  const Force(this.code);

  @override
  final String code;
}

/// Tryb obciążenia: zewnętrzne, masa ciała, masa ciała z dociążeniem, wspomaganie.
enum LoadMode implements CodedEnum {
  external('external'),
  bodyweight('bodyweight'),
  weightedBodyweight('weighted_bodyweight'),
  assisted('assisted');

  const LoadMode(this.code);

  @override
  final String code;
}

/// Co oznacza wpisany ciężar: łącznie, na rękę albo na stronę.
enum WeightSemantics implements CodedEnum {
  total('total'),
  perHand('per_hand'),
  perSide('per_side');

  const WeightSemantics(this.code);

  @override
  final String code;
}

enum ExerciseSource implements CodedEnum {
  builtin('builtin'),
  user('user');

  const ExerciseSource(this.code);

  @override
  final String code;
}

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
