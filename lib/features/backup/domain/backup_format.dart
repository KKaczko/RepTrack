import '../../../core/domain/coded_enum.dart';
import '../../../core/domain/training.dart';
import '../../exercises/domain/exercise.dart';
import '../../plan/domain/plan.dart';
import '../../workout/domain/workout_session.dart';

/// Format pliku kopii zapasowej (ADR 0008, docs/backup-format.md).
///
/// Mapowanie jest opisane jawnie, pole po polu, i nie zależy od kształtu
/// encji domeny ani klas Drift: plik ma własną wersję, niezależną od wersji
/// schematu bazy. Zmiana formatu wymaga nowej [backupFormatVersion]
/// i migracji w [backupMigrations].

/// Identyfikator formatu w polu `format`.
const backupFormatId = 'reptrack-backup';

/// Bieżąca wersja formatu.
const backupFormatVersion = 2;

/// Rodzaj wartości pola w pliku.
enum BackupFieldType {
  /// Identyfikator (UUIDv7 albo stały identyfikator z seeda).
  id,

  /// Dowolny tekst.
  text,

  /// Liczba całkowita.
  integer,

  /// Wartość logiczna.
  boolean,

  /// Moment w czasie: ISO 8601 UTC, np. `2026-10-19T16:05:00.000Z`.
  time,

  /// Data lokalna `YYYY-MM-DD`.
  date,

  /// Kod z zamkniętej listy (snake_case, ADR 0013).
  code,

  /// Lista tekstów.
  textList,

  /// Lista kodów z zamkniętej listy.
  codeList,
}

/// Pole tabeli w pliku i odpowiadająca mu kolumna bazy (schemat v1).
final class BackupField {
  const BackupField(
    this.json,
    this.column,
    this.type, {
    this.nullable = false,
    this.codes,
    this.references,
    this.min,
    this.max,
  });

  /// Nazwa w pliku (camelCase).
  final String json;

  /// Nazwa kolumny w bazie (snake_case).
  final String column;
  final BackupFieldType type;
  final bool nullable;

  /// Dozwolone kody dla [BackupFieldType.code] i [BackupFieldType.codeList].
  final Set<String>? codes;

  /// Tabela w pliku, do której odwołuje się identyfikator (klucz obcy).
  final String? references;

  /// Zakres liczby całkowitej.
  final int? min;
  final int? max;
}

/// Tabela w pliku: tablica obiektów pod kluczem [json].
final class BackupTable {
  const BackupTable(this.json, this.sql, this.fields);

  final String json;
  final String sql;
  final List<BackupField> fields;
}

Set<String> _codes(List<CodedEnum> values) => {for (final v in values) v.code};

/// Kolumny wspólne tabel synchronizowanych (ADR 0003).
const _sync = [
  BackupField('id', 'id', BackupFieldType.id),
  BackupField('createdAt', 'created_at', BackupFieldType.time),
  BackupField('updatedAt', 'updated_at', BackupFieldType.time),
  BackupField('deletedAt', 'deleted_at', BackupFieldType.time, nullable: true),
];

/// Tabele w kolejności wstawiania (najpierw te, do których odwołują się
/// klucze obce). Ustawienia są osobno, w [backupSettingsKey].
final List<BackupTable> backupTables = [
  BackupTable('exercises', 'exercises', [
    ..._sync,
    const BackupField('name', 'name', BackupFieldType.text),
    const BackupField('aliases', 'aliases', BackupFieldType.textList),
    const BackupField('searchText', 'search_text', BackupFieldType.text),
    BackupField(
      'primaryMuscles',
      'primary_muscles',
      BackupFieldType.codeList,
      codes: _codes(MuscleGroup.values),
    ),
    BackupField(
      'secondaryMuscles',
      'secondary_muscles',
      BackupFieldType.codeList,
      codes: _codes(MuscleGroup.values),
    ),
    BackupField(
      'equipment',
      'equipment',
      BackupFieldType.code,
      nullable: true,
      codes: _codes(Equipment.values),
    ),
    BackupField(
      'category',
      'category',
      BackupFieldType.code,
      codes: _codes(ExerciseCategory.values),
    ),
    BackupField(
      'mechanic',
      'mechanic',
      BackupFieldType.code,
      nullable: true,
      codes: _codes(Mechanic.values),
    ),
    BackupField(
      'force',
      'force',
      BackupFieldType.code,
      nullable: true,
      codes: _codes(Force.values),
    ),
    const BackupField(
      'instructions',
      'instructions',
      BackupFieldType.text,
      nullable: true,
    ),
    const BackupField(
      'measureWeight',
      'measure_weight',
      BackupFieldType.boolean,
    ),
    const BackupField('measureReps', 'measure_reps', BackupFieldType.boolean),
    const BackupField(
      'measureDuration',
      'measure_duration',
      BackupFieldType.boolean,
    ),
    const BackupField(
      'measureDistance',
      'measure_distance',
      BackupFieldType.boolean,
    ),
    BackupField(
      'loadMode',
      'load_mode',
      BackupFieldType.code,
      codes: _codes(LoadMode.values),
    ),
    BackupField(
      'weightSemantics',
      'weight_semantics',
      BackupFieldType.code,
      codes: _codes(WeightSemantics.values),
    ),
    const BackupField('isUnilateral', 'is_unilateral', BackupFieldType.boolean),
    const BackupField(
      'imageRef',
      'image_ref',
      BackupFieldType.text,
      nullable: true,
    ),
    BackupField(
      'source',
      'source',
      BackupFieldType.code,
      codes: _codes(ExerciseSource.values),
    ),
    const BackupField(
      'originRef',
      'origin_ref',
      BackupFieldType.text,
      nullable: true,
    ),
    const BackupField(
      'license',
      'license',
      BackupFieldType.text,
      nullable: true,
    ),
    const BackupField(
      'licenseAuthor',
      'license_author',
      BackupFieldType.text,
      nullable: true,
    ),
    const BackupField(
      'seedVersion',
      'seed_version',
      BackupFieldType.integer,
      nullable: true,
      min: 0,
    ),
    const BackupField('userModified', 'user_modified', BackupFieldType.boolean),
    const BackupField(
      'archivedAt',
      'archived_at',
      BackupFieldType.time,
      nullable: true,
    ),
  ]),
  const BackupTable('templates', 'templates', [
    ..._sync,
    BackupField('name', 'name', BackupFieldType.text),
    BackupField(
      'description',
      'description',
      BackupFieldType.text,
      nullable: true,
    ),
    BackupField(
      'archivedAt',
      'archived_at',
      BackupFieldType.time,
      nullable: true,
    ),
  ]),
  BackupTable('templateExercises', 'template_exercises', [
    ..._sync,
    const BackupField(
      'templateId',
      'template_id',
      BackupFieldType.id,
      references: 'templates',
    ),
    const BackupField(
      'exerciseId',
      'exercise_id',
      BackupFieldType.id,
      references: 'exercises',
    ),
    const BackupField('position', 'position', BackupFieldType.integer, min: 0),
    BackupField(
      'targetKind',
      'target_kind',
      BackupFieldType.code,
      codes: _codes(TargetKind.values),
    ),
    ..._targets,
    BackupField(
      'defaultSetType',
      'default_set_type',
      BackupFieldType.code,
      codes: _codes(SetType.values),
    ),
    const BackupField('note', 'note', BackupFieldType.text, nullable: true),
    const BackupField(
      'groupId',
      'group_id',
      BackupFieldType.text,
      nullable: true,
    ),
  ]),
  BackupTable('templateSets', 'template_sets', [
    ..._sync,
    const BackupField(
      'templateExerciseId',
      'template_exercise_id',
      BackupFieldType.id,
      references: 'templateExercises',
    ),
    const BackupField('position', 'position', BackupFieldType.integer, min: 0),
    BackupField(
      'setType',
      'set_type',
      BackupFieldType.code,
      nullable: true,
      codes: _codes(SetType.values),
    ),
    ..._targets,
  ]),
  BackupTable('workoutSessions', 'workout_sessions', [
    ..._sync,
    BackupField(
      'status',
      'status',
      BackupFieldType.code,
      codes: _codes(SessionStatus.values),
    ),
    const BackupField('startedAt', 'started_at', BackupFieldType.time),
    const BackupField(
      'endedAt',
      'ended_at',
      BackupFieldType.time,
      nullable: true,
    ),
    const BackupField('timeZone', 'time_zone', BackupFieldType.text),
    const BackupField('localDate', 'local_date', BackupFieldType.date),
    const BackupField(
      'templateId',
      'template_id',
      BackupFieldType.id,
      nullable: true,
      references: 'templates',
    ),
    const BackupField(
      'templateNameSnapshot',
      'template_name_snapshot',
      BackupFieldType.text,
      nullable: true,
    ),
    const BackupField('title', 'title', BackupFieldType.text, nullable: true),
    const BackupField('notes', 'notes', BackupFieldType.text, nullable: true),
    const BackupField(
      'wellbeing',
      'wellbeing',
      BackupFieldType.integer,
      nullable: true,
      min: 1,
      max: 5,
    ),
    const BackupField(
      'restEndsAt',
      'rest_ends_at',
      BackupFieldType.time,
      nullable: true,
    ),
  ]),
  BackupTable('sessionExercises', 'session_exercises', [
    ..._sync,
    const BackupField(
      'sessionId',
      'session_id',
      BackupFieldType.id,
      references: 'workoutSessions',
    ),
    const BackupField(
      'exerciseId',
      'exercise_id',
      BackupFieldType.id,
      references: 'exercises',
    ),
    const BackupField('position', 'position', BackupFieldType.integer, min: 0),
    // Bez klucza obcego: ćwiczenie szablonu może zostać usunięte, a sesja
    // zachowuje odwołanie do porównań („zaktualizuj szablon”).
    const BackupField(
      'templateExerciseId',
      'template_exercise_id',
      BackupFieldType.text,
      nullable: true,
    ),
    const BackupField(
      'exerciseNameSnapshot',
      'exercise_name_snapshot',
      BackupFieldType.text,
    ),
    const BackupField(
      'measureWeightSnapshot',
      'measure_weight_snapshot',
      BackupFieldType.boolean,
    ),
    const BackupField(
      'measureRepsSnapshot',
      'measure_reps_snapshot',
      BackupFieldType.boolean,
    ),
    const BackupField(
      'measureDurationSnapshot',
      'measure_duration_snapshot',
      BackupFieldType.boolean,
    ),
    const BackupField(
      'measureDistanceSnapshot',
      'measure_distance_snapshot',
      BackupFieldType.boolean,
    ),
    BackupField(
      'loadModeSnapshot',
      'load_mode_snapshot',
      BackupFieldType.code,
      codes: _codes(LoadMode.values),
    ),
    BackupField(
      'weightSemanticsSnapshot',
      'weight_semantics_snapshot',
      BackupFieldType.code,
      codes: _codes(WeightSemantics.values),
    ),
    const BackupField(
      'isUnilateralSnapshot',
      'is_unilateral_snapshot',
      BackupFieldType.boolean,
    ),
    const BackupField('note', 'note', BackupFieldType.text, nullable: true),
    const BackupField(
      'groupId',
      'group_id',
      BackupFieldType.text,
      nullable: true,
    ),
  ]),
  BackupTable('sessionSets', 'session_sets', [
    ..._sync,
    const BackupField(
      'sessionExerciseId',
      'session_exercise_id',
      BackupFieldType.id,
      references: 'sessionExercises',
    ),
    const BackupField('position', 'position', BackupFieldType.integer, min: 0),
    BackupField(
      'setType',
      'set_type',
      BackupFieldType.code,
      codes: _codes(SetType.values),
    ),
    BackupField(
      'targetKind',
      'target_kind',
      BackupFieldType.code,
      nullable: true,
      codes: _codes(TargetKind.values),
    ),
    ..._targets,
    const BackupField(
      'weightG',
      'weight_g',
      BackupFieldType.integer,
      nullable: true,
    ),
    const BackupField(
      'reps',
      'reps',
      BackupFieldType.integer,
      nullable: true,
      min: 0,
    ),
    const BackupField(
      'durationS',
      'duration_s',
      BackupFieldType.integer,
      nullable: true,
      min: 0,
    ),
    const BackupField(
      'distanceM',
      'distance_m',
      BackupFieldType.integer,
      nullable: true,
      min: 0,
    ),
    BackupField(
      'effortScale',
      'effort_scale',
      BackupFieldType.code,
      nullable: true,
      codes: _codes(EffortScale.values),
    ),
    const BackupField(
      'effortTenths',
      'effort_tenths',
      BackupFieldType.integer,
      nullable: true,
      min: 0,
    ),
    BackupField(
      'side',
      'side',
      BackupFieldType.code,
      nullable: true,
      codes: _codes(Side.values),
    ),
    const BackupField(
      'completedAt',
      'completed_at',
      BackupFieldType.time,
      nullable: true,
    ),
  ]),
  // Wersja 2: plan treningów (ADR 0015).
  const BackupTable('weeklyPlans', 'weekly_plans', [
    ..._sync,
    BackupField('startsOn', 'starts_on', BackupFieldType.date),
    BackupField('endsOn', 'ends_on', BackupFieldType.date, nullable: true),
  ]),
  const BackupTable('weeklyPlanDays', 'weekly_plan_days', [
    ..._sync,
    BackupField(
      'planId',
      'plan_id',
      BackupFieldType.id,
      references: 'weeklyPlans',
    ),
    BackupField('weekday', 'weekday', BackupFieldType.integer, min: 1, max: 7),
    BackupField(
      'templateId',
      'template_id',
      BackupFieldType.id,
      references: 'templates',
    ),
    BackupField('position', 'position', BackupFieldType.integer, min: 0),
  ]),
  BackupTable('plannedDays', 'planned_days', [
    ..._sync,
    const BackupField('date', 'date', BackupFieldType.date),
    BackupField(
      'kind',
      'kind',
      BackupFieldType.code,
      codes: _codes(PlannedKind.values),
    ),
    const BackupField(
      'templateId',
      'template_id',
      BackupFieldType.id,
      nullable: true,
      references: 'templates',
    ),
    const BackupField('position', 'position', BackupFieldType.integer, min: 0),
    const BackupField('note', 'note', BackupFieldType.text, nullable: true),
  ]),
];

/// Cele serii wspólne dla ćwiczeń i serii szablonu oraz serii sesji.
const _targets = [
  BackupField(
    'targetMin',
    'target_min',
    BackupFieldType.integer,
    nullable: true,
    min: 0,
  ),
  BackupField(
    'targetMax',
    'target_max',
    BackupFieldType.integer,
    nullable: true,
    min: 0,
  ),
  BackupField(
    'targetWeightG',
    'target_weight_g',
    BackupFieldType.integer,
    nullable: true,
  ),
  BackupField(
    'restSeconds',
    'rest_seconds',
    BackupFieldType.integer,
    nullable: true,
    min: 0,
  ),
];

/// Ustawienia: tablica `{key, value, updatedAt}`, wartość w dowolnym JSON.
const backupSettingsKey = 'settings';

/// JSON Schema (draft 2020-12) pliku kopii, generowana z [backupTables].
/// Zapisana w `docs/backup-format.schema.json`; zgodność pilnuje test.
Map<String, Object?> backupJsonSchema() {
  Map<String, Object?> fieldSchema(BackupField field) {
    final Map<String, Object?> base = switch (field.type) {
      BackupFieldType.id => {'type': 'string', 'minLength': 1},
      BackupFieldType.text => {'type': 'string'},
      BackupFieldType.integer => {
        'type': 'integer',
        'minimum': ?field.min,
        'maximum': ?field.max,
      },
      BackupFieldType.boolean => {'type': 'boolean'},
      BackupFieldType.time => {'type': 'string', 'format': 'date-time'},
      BackupFieldType.date => {'type': 'string', 'format': 'date'},
      BackupFieldType.code => {'enum': field.codes!.toList()..sort()},
      BackupFieldType.textList => {
        'type': 'array',
        'items': {'type': 'string'},
      },
      BackupFieldType.codeList => {
        'type': 'array',
        'items': {'enum': field.codes!.toList()..sort()},
      },
    };
    if (!field.nullable) return base;
    if (base.containsKey('enum')) {
      return {
        'enum': [...base['enum']! as List, null],
      };
    }
    return {
      'anyOf': [
        base,
        {'type': 'null'},
      ],
    };
  }

  return {
    r'$schema': 'https://json-schema.org/draft/2020-12/schema',
    r'$id': 'urn:reptrack:backup-format:1',
    'title': 'RepTrack backup',
    'type': 'object',
    'required': [
      'format',
      'formatVersion',
      'exportedAt',
      for (final t in backupTables) t.json,
      backupSettingsKey,
    ],
    'properties': {
      'format': {'const': backupFormatId},
      'formatVersion': {'const': backupFormatVersion},
      'appVersion': {'type': 'string'},
      'exportedAt': {'type': 'string', 'format': 'date-time'},
      'units': {'type': 'object'},
      for (final table in backupTables)
        table.json: {
          'type': 'array',
          'items': {
            'type': 'object',
            'required': [
              for (final f in table.fields)
                if (!f.nullable) f.json,
            ],
            'properties': {
              for (final f in table.fields) f.json: fieldSchema(f),
            },
          },
        },
      backupSettingsKey: {
        'type': 'array',
        'items': {
          'type': 'object',
          'required': ['key', 'value', 'updatedAt'],
          'properties': {
            'key': {'type': 'string'},
            'value': <String, Object?>{},
            'updatedAt': {'type': 'string', 'format': 'date-time'},
          },
        },
      },
    },
  };
}
