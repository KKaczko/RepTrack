import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:reptrack/core/database/app_database.dart';
import 'package:reptrack/core/domain/clock.dart';
import 'package:reptrack/features/exercises/data/drift_exercise_repository.dart';
import 'package:reptrack/features/exercises/data/exercise_seeder.dart';
import 'package:reptrack/features/exercises/data/seed_catalog.dart';

import '../../../support/test_database.dart';

void main() {
  late AppDatabase db;
  late FixedClock clock;
  late ExerciseSeeder seeder;
  late DriftExerciseRepository repo;
  final catalog = parseSeedCatalog(File(seedAssetPath).readAsStringSync());

  SeedCatalog bumped(SeedCatalog base, {required int version}) => SeedCatalog(
    seedVersion: version,
    exercises: [
      for (final e in base.exercises)
        e.copyWith(name: '${e.name} v$version', seedVersion: version),
    ],
  );

  setUp(() {
    db = memoryDatabase();
    clock = testClock();
    seeder = ExerciseSeeder(db, clock);
    repo = DriftExerciseRepository(db, clock);
  });
  tearDown(() => db.close());

  test('pierwsze uruchomienie dodaje całą bibliotekę', () async {
    final result = await seeder.apply(catalog);

    expect(result.applied, isTrue);
    expect(result.inserted, catalog.exercises.length);
    final stored = await repo.watchAll().first;
    expect(stored, hasLength(catalog.exercises.length));
    final bench = catalog.exercises.first;
    expect(await repo.findById(bench.id), bench);
  });

  test('ta sama wersja nie robi nic', () async {
    await seeder.apply(catalog);

    final again = await seeder.apply(catalog);

    expect(again.applied, isFalse);
  });

  test(
    'nowsza wersja aktualizuje, ale nie nadpisuje zmian użytkownika',
    () async {
      await seeder.apply(catalog);
      final edited = catalog.exercises[0];
      final archived = catalog.exercises[1];
      await repo.save(edited.copyWith(name: 'Moja klata', userModified: true));
      await repo.setArchived(archived.id, archived: true);

      clock.advance(const Duration(days: 30));
      final next = catalog.seedVersion + 1;
      final result = await seeder.apply(bumped(catalog, version: next));

      expect(result.updated, catalog.exercises.length - 1);
      expect(result.skippedUserModified, 1);
      expect((await repo.findById(edited.id))!.name, 'Moja klata');
      final archivedNow = (await repo.findById(archived.id))!;
      expect(archivedNow.name, '${archived.name} v$next');
      expect(archivedNow.isArchived, isTrue);
    },
  );

  test('ćwiczenia własne użytkownika nie są ruszane', () async {
    await repo.save(testExercise('moje', name: 'Moje ćwiczenie'));

    await seeder.apply(catalog);
    await seeder.apply(bumped(catalog, version: catalog.seedVersion + 1));

    expect((await repo.findById('moje'))!.name, 'Moje ćwiczenie');
  });

  test('pozycja usunięta z nowego seeda zostaje w bazie', () async {
    await seeder.apply(catalog);
    final shorter = SeedCatalog(
      seedVersion: catalog.seedVersion + 1,
      exercises: catalog.exercises.skip(1).toList(),
    );

    await seeder.apply(shorter);

    expect(await repo.findById(catalog.exercises.first.id), isNotNull);
  });

  test('seed v1 → v2: dochodzą ćwiczenia z masą ciała (ADR 0019)', () async {
    final v1 = SeedCatalog(
      seedVersion: 1,
      exercises: [
        for (final e in catalog.exercises)
          if (e.seedVersion == 1) e,
      ],
    );
    await seeder.apply(v1);

    final result = await seeder.apply(catalog);

    expect(catalog.seedVersion, 2);
    expect(result.inserted, 4);
    expect(result.updated, 0);
    final names = {for (final e in await repo.watchAll().first) e.name};
    expect(names, contains('Przysiad bez obciążenia'));
    expect(names, contains('Mostek biodrowy bez obciążenia'));
  });
}
