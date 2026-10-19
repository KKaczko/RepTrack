// Kolumny z .check() odwołują się do własnego gettera: to wzorzec Drift.
// ignore_for_file: recursive_getters

import 'package:drift/drift.dart';

import '../../features/exercises/domain/exercise.dart';
import '../../features/workout/domain/workout_session.dart';
import '../domain/training.dart';
import 'converters.dart';

/// Kolumny wspólne rekordów synchronizowalnych (ADR 0003): UUIDv7 jako klucz,
/// znaczniki czasu w epoch ms UTC i miękkie usuwanie.
mixin SyncColumns on Table {
  TextColumn get id => text()();
  IntColumn get createdAt => integer().map(const UtcMillisConverter())();
  IntColumn get updatedAt => integer().map(const UtcMillisConverter())();
  IntColumn get deletedAt =>
      integer().map(const UtcMillisConverter()).nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('ExerciseRow')
@TableIndex(name: 'idx_exercises_source', columns: {#source})
class Exercises extends Table with SyncColumns {
  TextColumn get name => text()();
  TextColumn get aliases => text().map(const StringListConverter())();
  TextColumn get searchText => text()();
  TextColumn get primaryMuscles => text().map(
    const CodedEnumListConverter<MuscleGroup>(MuscleGroup.values),
  )();
  TextColumn get secondaryMuscles => text().map(
    const CodedEnumListConverter<MuscleGroup>(MuscleGroup.values),
  )();
  TextColumn get equipment => text()
      .map(const CodedEnumConverter<Equipment>(Equipment.values))
      .nullable()();
  TextColumn get category => text().map(
    const CodedEnumConverter<ExerciseCategory>(ExerciseCategory.values),
  )();
  TextColumn get mechanic => text()
      .map(const CodedEnumConverter<Mechanic>(Mechanic.values))
      .nullable()();
  TextColumn get force =>
      text().map(const CodedEnumConverter<Force>(Force.values)).nullable()();
  TextColumn get instructions => text().nullable()();
  BoolColumn get measureWeight => boolean()();
  BoolColumn get measureReps => boolean()();
  BoolColumn get measureDuration => boolean()();
  BoolColumn get measureDistance => boolean()();
  TextColumn get loadMode =>
      text().map(const CodedEnumConverter<LoadMode>(LoadMode.values))();
  TextColumn get weightSemantics => text().map(
    const CodedEnumConverter<WeightSemantics>(WeightSemantics.values),
  )();
  BoolColumn get isUnilateral => boolean()();
  TextColumn get imageRef => text().nullable()();
  TextColumn get source => text().map(
    const CodedEnumConverter<ExerciseSource>(ExerciseSource.values),
  )();
  TextColumn get originRef => text().nullable()();
  TextColumn get license => text().nullable()();
  TextColumn get licenseAuthor => text().nullable()();
  IntColumn get seedVersion => integer().nullable()();
  BoolColumn get userModified => boolean()();
  IntColumn get archivedAt =>
      integer().map(const UtcMillisConverter()).nullable()();

  @override
  List<String> get customConstraints => [
    'CHECK (measure_weight OR measure_reps OR measure_duration OR measure_distance)',
  ];
}

@DataClassName('TemplateRow')
class Templates extends Table with SyncColumns {
  TextColumn get name => text()();
  TextColumn get description => text().nullable()();
  IntColumn get archivedAt =>
      integer().map(const UtcMillisConverter()).nullable()();
}

@DataClassName('TemplateExerciseRow')
@TableIndex(
  name: 'idx_template_exercises_template',
  columns: {#templateId, #position},
)
@TableIndex(name: 'idx_template_exercises_exercise', columns: {#exerciseId})
class TemplateExercises extends Table with SyncColumns {
  TextColumn get templateId => text().references(Templates, #id)();
  TextColumn get exerciseId => text().references(Exercises, #id)();
  IntColumn get position => integer()();
  TextColumn get targetKind =>
      text().map(const CodedEnumConverter<TargetKind>(TargetKind.values))();
  IntColumn get targetMin => integer().nullable()();
  IntColumn get targetMax => integer().nullable()();
  IntColumn get targetWeightG => integer().nullable()();
  IntColumn get restSeconds => integer().nullable()();
  TextColumn get defaultSetType =>
      text().map(const CodedEnumConverter<SetType>(SetType.values))();
  TextColumn get note => text().nullable()();
  TextColumn get groupId => text().nullable()();
}

/// Serie szablonu. Pole równe NULL dziedziczy wartość z ćwiczenia (ADR 0004).
@DataClassName('TemplateSetRow')
@TableIndex(
  name: 'idx_template_sets_template_exercise',
  columns: {#templateExerciseId, #position},
)
class TemplateSets extends Table with SyncColumns {
  TextColumn get templateExerciseId =>
      text().references(TemplateExercises, #id)();
  IntColumn get position => integer()();
  TextColumn get setType => text()
      .map(const CodedEnumConverter<SetType>(SetType.values))
      .nullable()();
  IntColumn get targetMin => integer().nullable()();
  IntColumn get targetMax => integer().nullable()();
  IntColumn get targetWeightG => integer().nullable()();
  IntColumn get restSeconds => integer().nullable()();
}

@DataClassName('WorkoutSessionRow')
@TableIndex.sql(
  'CREATE UNIQUE INDEX ux_workout_sessions_one_active ON workout_sessions '
  "(status) WHERE status = 'active' AND deleted_at IS NULL",
)
@TableIndex(name: 'idx_workout_sessions_local_date', columns: {#localDate})
@TableIndex(name: 'idx_workout_sessions_started_at', columns: {#startedAt})
@TableIndex(
  name: 'idx_workout_sessions_template',
  columns: {#templateId, #startedAt},
)
class WorkoutSessions extends Table with SyncColumns {
  TextColumn get status => text().map(
    const CodedEnumConverter<SessionStatus>(SessionStatus.values),
  )();
  IntColumn get startedAt => integer().map(const UtcMillisConverter())();
  IntColumn get endedAt =>
      integer().map(const UtcMillisConverter()).nullable()();
  TextColumn get timeZone => text()();
  TextColumn get localDate => text().map(const LocalDateConverter())();
  TextColumn get templateId => text().nullable().references(Templates, #id)();
  TextColumn get templateNameSnapshot => text().nullable()();
  TextColumn get title => text().nullable()();
  TextColumn get notes => text().nullable()();
  IntColumn get wellbeing =>
      integer().nullable().check(wellbeing.isBetweenValues(1, 5))();
  IntColumn get restEndsAt =>
      integer().map(const UtcMillisConverter()).nullable()();
}

@DataClassName('SessionExerciseRow')
@TableIndex(
  name: 'idx_session_exercises_session',
  columns: {#sessionId, #position},
)
@TableIndex(name: 'idx_session_exercises_exercise', columns: {#exerciseId})
class SessionExercises extends Table with SyncColumns {
  TextColumn get sessionId => text().references(WorkoutSessions, #id)();
  TextColumn get exerciseId => text().references(Exercises, #id)();
  IntColumn get position => integer()();

  /// Słabe powiązanie z ćwiczeniem szablonu, do diffu „zaktualizuj szablon”.
  TextColumn get templateExerciseId => text().nullable()();
  TextColumn get exerciseNameSnapshot => text()();
  BoolColumn get measureWeightSnapshot => boolean()();
  BoolColumn get measureRepsSnapshot => boolean()();
  BoolColumn get measureDurationSnapshot => boolean()();
  BoolColumn get measureDistanceSnapshot => boolean()();
  TextColumn get loadModeSnapshot =>
      text().map(const CodedEnumConverter<LoadMode>(LoadMode.values))();
  TextColumn get weightSemanticsSnapshot => text().map(
    const CodedEnumConverter<WeightSemantics>(WeightSemantics.values),
  )();
  BoolColumn get isUnilateralSnapshot => boolean()();
  TextColumn get note => text().nullable()();
  TextColumn get groupId => text().nullable()();
}

@DataClassName('SessionSetRow')
@TableIndex(
  name: 'idx_session_sets_session_exercise',
  columns: {#sessionExerciseId, #position},
)
class SessionSets extends Table with SyncColumns {
  TextColumn get sessionExerciseId =>
      text().references(SessionExercises, #id)();
  IntColumn get position => integer()();
  TextColumn get setType =>
      text().map(const CodedEnumConverter<SetType>(SetType.values))();
  TextColumn get targetKind => text()
      .map(const CodedEnumConverter<TargetKind>(TargetKind.values))
      .nullable()();
  IntColumn get targetMin => integer().nullable()();
  IntColumn get targetMax => integer().nullable()();
  IntColumn get targetWeightG => integer().nullable()();
  IntColumn get restSeconds => integer().nullable()();
  IntColumn get weightG => integer().nullable()();
  IntColumn get reps =>
      integer().nullable().check(reps.isBiggerOrEqualValue(0))();
  IntColumn get durationS =>
      integer().nullable().check(durationS.isBiggerOrEqualValue(0))();
  IntColumn get distanceM =>
      integer().nullable().check(distanceM.isBiggerOrEqualValue(0))();
  TextColumn get effortScale => text()
      .map(const CodedEnumConverter<EffortScale>(EffortScale.values))
      .nullable()();
  IntColumn get effortTenths => integer().nullable()();
  TextColumn get side =>
      text().map(const CodedEnumConverter<Side>(Side.values)).nullable()();
  IntColumn get completedAt =>
      integer().map(const UtcMillisConverter()).nullable()();
}

/// Ustawienia jako pary klucz → wartość JSON (ADR 0010).
@DataClassName('SettingRow')
class Settings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();
  IntColumn get updatedAt => integer().map(const UtcMillisConverter())();

  @override
  Set<Column<Object>> get primaryKey => {key};
}
