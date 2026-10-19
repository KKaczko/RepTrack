import 'package:flutter_test/flutter_test.dart';
import 'package:reptrack/core/database/app_database.dart';
import 'package:reptrack/core/domain/clock.dart';
import 'package:reptrack/core/domain/training.dart';
import 'package:reptrack/features/exercises/data/drift_exercise_repository.dart';
import 'package:reptrack/features/templates/data/drift_template_repository.dart';
import 'package:reptrack/features/templates/domain/set_plan.dart';
import 'package:reptrack/features/templates/domain/template.dart';

import '../../../support/fakes.dart';
import '../../../support/test_database.dart';

Template _push() => const Template(
  id: 't1',
  name: 'Push A',
  description: 'Klatka i barki',
  exercises: [
    TemplateExercise(
      id: 'te-bench',
      exerciseId: 'bench',
      position: 0,
      targetMin: 8,
      targetMax: 12,
      targetWeightG: 80000,
      restSeconds: 150,
      sets: [
        TemplateSet(id: 'b0', position: 0, setType: SetType.warmup),
        TemplateSet(id: 'b1', position: 1),
        TemplateSet(id: 'b2', position: 2, targetMin: 6, targetMax: 8),
      ],
    ),
    TemplateExercise(
      id: 'te-ohp',
      exerciseId: 'ohp',
      position: 1,
      targetMin: 10,
      targetMax: 10,
      groupId: 'superset-1',
      sets: [TemplateSet(id: 'o0', position: 0)],
    ),
  ],
);

void main() {
  late AppDatabase db;
  late FixedClock clock;
  late DriftTemplateRepository repo;

  setUp(() async {
    db = memoryDatabase();
    clock = testClock();
    repo = DriftTemplateRepository(db, clock);
    final exercises = DriftExerciseRepository(db, clock);
    for (final id in ['bench', 'ohp', 'dips']) {
      await exercises.save(testExercise(id));
    }
  });
  tearDown(() => db.close());

  test('zapis i odczyt całego szablonu z nadpisaniami serii', () async {
    await repo.save(_push());

    final loaded = await repo.findById('t1');

    expect(loaded, _push());
    final sets = resolveEffectiveSets(loaded!.exercises.first);
    expect(sets.first.setType, SetType.warmup);
    expect((sets[2].targetMin, sets[2].targetMax), (6, 8));
  });

  test(
    'usunięte ćwiczenie i seria są miękko usuwane, reszta bez zmian',
    () async {
      await repo.save(_push());
      clock.advance(const Duration(minutes: 5));

      final edited = _push().copyWith(
        exercises: [
          withSetCount(_push().exercises.first, 2, SequentialIds()),
          const TemplateExercise(
            id: 'te-dips',
            exerciseId: 'dips',
            position: 1,
            sets: [TemplateSet(id: 'd0', position: 0)],
          ),
        ],
      );
      await repo.save(edited);

      expect(await repo.findById('t1'), edited);
      final deletedSets = await (db.select(
        db.templateSets,
      )..where((t) => t.deletedAt.isNotNull())).get();
      expect({for (final s in deletedSets) s.id}, {'b2', 'o0'});
      final ohp = await (db.select(
        db.templateExercises,
      )..where((t) => t.id.equals('te-ohp'))).getSingle();
      expect(ohp.deletedAt, isNotNull);
    },
  );

  test('niezmienione wiersze zachowują updated_at', () async {
    await repo.save(_push());
    clock.advance(const Duration(minutes: 5));

    await repo.save(
      _push().copyWith(
        exercises: [
          overrideSet(_push().exercises.first, 1, targetWeightG: 85000),
          _push().exercises[1],
        ],
      ),
    );

    final sets = {
      for (final s in await db.select(db.templateSets).get()) s.id: s,
    };
    final t0 = DateTime.utc(2026, 10, 19, 18);
    expect(sets['b0']!.updatedAt, t0);
    expect(sets['b1']!.updatedAt, t0.add(const Duration(minutes: 5)));
    expect(sets['b1']!.createdAt, t0);
    final template = await db.select(db.templates).getSingle();
    expect(template.updatedAt, t0, reason: 'nazwa i opis bez zmian');
  });

  test('archiwizacja i usunięcie ukrywają szablon na liście', () async {
    await repo.save(_push());
    await repo.save(const Template(id: 't2', name: 'Arms'));

    await repo.setArchived('t1', archived: true);
    expect([for (final t in await repo.watchAll().first) t.id], ['t2']);
    expect(await repo.watchAll(includeArchived: true).first, hasLength(2));

    await repo.delete('t2');
    expect(await repo.watchAll().first, isEmpty);
    expect(await repo.findById('t2'), isNull);
  });

  test('watchAll emituje po zmianie serii', () async {
    await repo.save(_push());
    final stream = repo.watchAll();

    final emissions = <int>[];
    final sub = stream.listen(
      (templates) => emissions.add(templates.single.exercises.first.setCount),
    );
    await pumpEventQueue();
    await repo.save(
      _push().copyWith(
        exercises: [withSetCount(_push().exercises.first, 5, SequentialIds())],
      ),
    );
    await pumpEventQueue();
    await sub.cancel();

    expect(emissions.first, 3);
    expect(emissions.last, 5);
  });
}
