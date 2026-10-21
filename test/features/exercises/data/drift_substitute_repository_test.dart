import 'package:flutter_test/flutter_test.dart';
import 'package:reptrack/core/database/app_database.dart';
import 'package:reptrack/features/exercises/data/drift_exercise_repository.dart';
import 'package:reptrack/features/exercises/data/drift_substitute_repository.dart';

import '../../../support/fakes.dart';
import '../../../support/test_database.dart';
import '../../../support/workout_fixtures.dart';

void main() {
  late AppDatabase db;
  late DriftSubstituteRepository repo;

  setUp(() async {
    db = memoryDatabase();
    repo = DriftSubstituteRepository(db, testClock(), SequentialIds('s'));
    for (final e in catalog.values) {
      await DriftExerciseRepository(db, testClock()).save(e);
    }
  });
  tearDown(() => db.close());

  Future<List<(String, String)>> pins() async => [
    for (final p in await repo.watch().first) (p.exerciseId, p.substituteId),
  ];

  test('przypięcie w kolejności, bez duplikatów w obie strony', () async {
    await repo.pin('bench', 'pushup');
    await repo.pin('bench', 'pullup');
    await repo.pin('pushup', 'bench');
    await repo.pin('bench', 'bench');

    expect(await pins(), [('bench', 'pushup'), ('bench', 'pullup')]);
  });

  test('odpięcie w którąkolwiek stronę jest miękkie', () async {
    await repo.pin('bench', 'pushup');
    await repo.unpin('pushup', 'bench');

    expect(await pins(), isEmpty);
    final rows = await db.select(db.exerciseSubstitutes).get();
    expect(rows.single.deletedAt, isNotNull);

    // Ponowne przypięcie tworzy nowy wiersz.
    await repo.pin('bench', 'pushup');
    expect(await pins(), [('bench', 'pushup')]);
  });

  test('strumień oddaje piny po zmianie', () async {
    final expectation = expectLater(
      repo.watch().map((p) => p.length),
      emitsThrough(1),
    );
    await repo.pin('bench', 'pushup');
    await expectation;
  });
}
