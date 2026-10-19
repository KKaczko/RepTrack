import 'package:flutter_test/flutter_test.dart';
import 'package:reptrack/core/database/app_database.dart';
import 'package:reptrack/core/domain/clock.dart';
import 'package:reptrack/features/exercises/data/drift_exercise_repository.dart';
import 'package:reptrack/features/exercises/domain/exercise.dart';
import 'package:reptrack/features/exercises/domain/exercise_repository.dart';
import 'package:reptrack/features/templates/data/drift_template_repository.dart';
import 'package:reptrack/features/templates/domain/template.dart';

import '../../../support/test_database.dart';

void main() {
  late AppDatabase db;
  late FixedClock clock;
  late DriftExerciseRepository repo;

  setUp(() {
    db = memoryDatabase();
    clock = testClock();
    repo = DriftExerciseRepository(db, clock);
  });
  tearDown(() => db.close());

  test('zapis i odczyt zachowują wszystkie pola', () async {
    final exercise = testExercise('e1').copyWith(
      force: Force.push,
      mechanic: Mechanic.compound,
      loadMode: LoadMode.weightedBodyweight,
      weightSemantics: WeightSemantics.perHand,
      isUnilateral: true,
      instructions: 'Łopatki ściągnięte.',
      license: 'Unlicense',
    );

    await repo.save(exercise);

    expect(await repo.findById('e1'), exercise);
  });

  test(
    'zapis ustawia search_text bez diakrytyków i zachowuje created_at',
    () async {
      await repo.save(testExercise('e1', name: 'Wyciskanie na ławce'));
      clock.advance(const Duration(hours: 1));
      await repo.save(testExercise('e1', name: 'Wyciskanie na ławce skośnej'));

      final row = await db.select(db.exercises).getSingle();
      expect(row.searchText, 'wyciskanie na lawce skosnej alias');
      expect(row.createdAt, DateTime.utc(2026, 10, 19, 18));
      expect(row.updatedAt, DateTime.utc(2026, 10, 19, 19));
    },
  );

  test('odrzuca ćwiczenie bez mierzonych pól', () {
    expect(
      () => repo.save(testExercise('e1', measurement: const Measurement())),
      throwsArgumentError,
    );
  });

  test(
    'katalog jest posortowany bez względu na polskie znaki i pomija archiwum',
    () async {
      await repo.save(testExercise('z', name: 'Żuraw'));
      await repo.save(testExercise('l', name: 'Ławka'));
      await repo.save(testExercise('m', name: 'Martwy ciąg'));
      await repo.save(testExercise('a', name: 'Arnoldki'));
      await repo.setArchived('m', archived: true);

      final active = await repo.watchAll().first;
      final all = await repo.watchAll(includeArchived: true).first;

      expect([for (final e in active) e.name], ['Arnoldki', 'Ławka', 'Żuraw']);
      expect(all, hasLength(4));
      expect(all.firstWhere((e) => e.id == 'm').isArchived, isTrue);
    },
  );

  test(
    'ćwiczenia użytego w szablonie nie można usunąć, tylko zarchiwizować',
    () async {
      await repo.save(testExercise('used'));
      await repo.save(testExercise('free'));
      await DriftTemplateRepository(db, clock).save(
        const Template(
          id: 't1',
          name: 'Push',
          exercises: [
            TemplateExercise(
              id: 'te1',
              exerciseId: 'used',
              position: 0,
              sets: [TemplateSet(id: 's1', position: 0)],
            ),
          ],
        ),
      );

      expect(await repo.isInUse('used'), isTrue);
      expect(await repo.isInUse('free'), isFalse);
      await expectLater(
        repo.delete('used'),
        throwsA(isA<ExerciseInUseException>()),
      );

      await repo.delete('free');
      expect(await repo.findById('free'), isNull);
      expect(await repo.watchAll(includeArchived: true).first, hasLength(1));
    },
  );
}
