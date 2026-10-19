import 'package:flutter_test/flutter_test.dart';
import 'package:reptrack/core/domain/coded_enum.dart';
import 'package:reptrack/core/domain/training.dart';
import 'package:reptrack/core/domain/units.dart';
import 'package:reptrack/features/exercises/domain/exercise.dart';
import 'package:reptrack/features/settings/domain/app_settings.dart';
import 'package:reptrack/features/workout/domain/workout_session.dart';

/// Kody enumów trafiają do bazy i backupu (ADR 0013). Ten test celowo
/// przypina każdy kod: jego zmiana wymaga migracji, a nie tylko edycji testu.
const _expectedCodes = <String, List<String>>{
  'MuscleGroup': [
    'abdominals', 'abductors', 'adductors', 'biceps', 'calves', 'chest', //
    'forearms', 'glutes', 'hamstrings', 'lats', 'lower_back', 'middle_back',
    'neck', 'quadriceps', 'shoulders', 'traps', 'triceps',
  ],
  'Equipment': [
    'barbell', 'dumbbell', 'kettlebell', 'cable', 'machine', 'smith_machine',
    'ez_bar', 'bodyweight', 'bands', 'medicine_ball', 'exercise_ball', //
    'foam_roll', 'other',
  ],
  'ExerciseCategory': [
    'strength',
    'cardio',
    'mobility',
    'plyometrics',
    'olympic',
    'strongman',
  ],
  'Mechanic': ['compound', 'isolation'],
  'Force': ['push', 'pull', 'static'],
  'LoadMode': ['external', 'bodyweight', 'weighted_bodyweight', 'assisted'],
  'WeightSemantics': ['total', 'per_hand', 'per_side'],
  'ExerciseSource': ['builtin', 'user'],
  'SetType': ['warmup', 'working', 'drop', 'amrap'],
  'TargetKind': ['reps', 'duration'],
  'EffortScale': ['rir', 'rpe'],
  'SessionStatus': ['active', 'completed', 'discarded'],
  'Side': ['both', 'left', 'right'],
  'AppThemeMode': ['dark', 'light', 'system'],
  'WeightUnit': ['kg', 'lb'],
};

const _allEnums = <String, List<CodedEnum>>{
  'MuscleGroup': MuscleGroup.values,
  'Equipment': Equipment.values,
  'ExerciseCategory': ExerciseCategory.values,
  'Mechanic': Mechanic.values,
  'Force': Force.values,
  'LoadMode': LoadMode.values,
  'WeightSemantics': WeightSemantics.values,
  'ExerciseSource': ExerciseSource.values,
  'SetType': SetType.values,
  'TargetKind': TargetKind.values,
  'EffortScale': EffortScale.values,
  'SessionStatus': SessionStatus.values,
  'Side': Side.values,
  'AppThemeMode': AppThemeMode.values,
  'WeightUnit': WeightUnit.values,
};

final _snakeCase = RegExp(r'^[a-z][a-z0-9]*(_[a-z0-9]+)*$');

void main() {
  test('każdy enum ma przypięte kody', () {
    expect(_allEnums.keys.toSet(), _expectedCodes.keys.toSet());
  });

  for (final MapEntry(key: name, value: values) in _allEnums.entries) {
    group(name, () {
      final codes = [for (final v in values) v.code];

      test('kody są takie jak w docs/data-model.md', () {
        expect(codes, _expectedCodes[name]);
      });

      test('kody są w snake_case i unikalne', () {
        expect(codes.every(_snakeCase.hasMatch), isTrue, reason: '$codes');
        expect(codes.toSet(), hasLength(codes.length));
      });

      test('kod da się odczytać z powrotem', () {
        for (final value in values) {
          expect(enumFromCode(values, value.code), same(value));
        }
      });
    });
  }

  test('nieznany kod jest odrzucany albo daje null', () {
    expect(
      () => enumFromCode(LoadMode.values, 'weightedBodyweight'),
      throwsFormatException,
    );
    expect(tryEnumFromCode(LoadMode.values, 'nieznany'), isNull);
    expect(tryEnumFromCode(LoadMode.values, null), isNull);
    expect(
      tryEnumFromCode(LoadMode.values, 'weighted_bodyweight'),
      LoadMode.weightedBodyweight,
    );
  });
}
