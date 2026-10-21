import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:reptrack/core/domain/exercise_groups.dart';
import 'package:reptrack/core/domain/local_date.dart';
import 'package:reptrack/core/domain/training.dart';
import 'package:reptrack/features/exercises/data/seed_catalog.dart';
import 'package:reptrack/features/exercises/domain/exercise.dart';
import 'package:reptrack/features/plan/domain/plan.dart';
import 'package:reptrack/features/programs/domain/program.dart';
import 'package:reptrack/features/programs/domain/program_install.dart';

import '../../../support/fakes.dart';

void main() {
  final seed = File(seedAssetPath).readAsStringSync();
  final catalog = parseSeedCatalog(seed);
  final byId = {for (final e in catalog.exercises) e.id: e};
  final exercisesByKey = <String, Exercise>{
    for (final MapEntry(:key, :value) in seedIdsByKey(seed).entries)
      key: byId[value]!,
  };
  final programs = parsePrograms(File(programsAssetPath).readAsStringSync());

  group('biblioteka programów', () {
    test('7 programów, każdy poprawny wobec biblioteki ćwiczeń', () {
      expect(programs, hasLength(7));
      expect({for (final p in programs) p.id}, hasLength(7));
      for (final program in programs) {
        expect(
          validateProgram(program, exercisesByKey),
          isEmpty,
          reason: program.id,
        );
      }
    });

    test('teksty PL i EN oraz spójne superserie', () {
      for (final program in programs) {
        for (final text in [program.name, program.description]) {
          expect(text.pl, isNotEmpty);
          expect(text.en, isNotEmpty);
          expect(text.en, isNot(text.pl), reason: program.id);
        }
        for (final workout in program.workouts) {
          final markers = [for (final e in workout.exercises) e.superset];
          // Znaczniki superserii to ciągłe odcinki co najmniej 2 ćwiczeń.
          expect(
            normalizeGroupIds(markers),
            markers,
            reason: '${program.id}/${workout.key}',
          );
        }
      }
    });

    test('filtry mają co pokazać: 2, 3 i 4 dni, każdy sprzęt', () {
      expect({for (final p in programs) p.daysPerWeek}, {2, 3, 4});
      expect({
        for (final p in programs) p.equipment,
      }, ProgramEquipment.values.toSet());
    });

    test('nieobsługiwany format jest odrzucany', () {
      expect(
        () => parsePrograms('{"formatVersion": 2, "programs": []}'),
        throwsFormatException,
      );
      expect(
        () => parsePrograms('{"formatVersion": 1, "programs": [{}]}'),
        throwsFormatException,
      );
    });
  });

  group('dodanie programu', () {
    final program = programs.firstWhere((p) => p.id == 'fbw_beginner_3');
    const today = LocalDate(2026, 10, 19);

    test('szablony z celami, przerwami i superserią oraz plan od dziś', () {
      final result = installProgram(
        program,
        exercisesByKey: exercisesByKey,
        languageCode: 'pl',
        plans: const [],
        today: today,
        ids: SequentialIds('p'),
      );

      expect(
        [for (final t in result.templates) t.name],
        ['FBW A', 'FBW B', 'FBW C'],
      );
      expect(
        result.templates.first.description,
        'FBW na start (3× w tygodniu)',
      );
      final squat = result.templates.first.exercises.first;
      expect(squat.exerciseId, exercisesByKey['back_squat']!.id);
      expect(
        (squat.targetKind, squat.targetMin, squat.targetMax, squat.restSeconds),
        (TargetKind.reps, 6, 10, 150),
      );
      expect(squat.sets, hasLength(3));
      final plank = result.templates.first.exercises.last;
      expect(plank.targetKind, TargetKind.duration);
      // Biceps i triceps w FBW C to superseria.
      final c = result.templates.last.exercises;
      expect(c[4].groupId, isNotNull);
      expect(c[5].groupId, c[4].groupId);
      expect(c[3].groupId, isNull);

      final plan = result.plan.save.single;
      expect(plan.startsOn, today);
      expect(
        {for (final d in plan.days) d.weekday: d.templateId},
        {
          1: result.templates[0].id,
          3: result.templates[1].id,
          5: result.templates[2].id,
        },
      );
    });

    test('działający plan tygodniowy jest zamykany na wczoraj', () {
      const running = WeeklyPlan(
        id: 'old',
        startsOn: LocalDate(2026, 10, 5),
        days: [
          WeeklyPlanDay(id: 'd', weekday: 2, templateId: 'x', position: 0),
        ],
      );

      final result = installProgram(
        program,
        exercisesByKey: exercisesByKey,
        languageCode: 'en',
        plans: [running],
        today: today,
        ids: SequentialIds('p'),
      );

      expect(result.templates.first.name, 'Full body A');
      final closed = result.plan.save.firstWhere((p) => p.id == 'old');
      expect(closed.endsOn, const LocalDate(2026, 10, 18));
      expect(result.plan.save, hasLength(2));
    });
  });
}
