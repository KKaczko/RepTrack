import 'package:flutter_test/flutter_test.dart';
import 'package:reptrack/features/exercises/domain/exercise.dart';
import 'package:reptrack/features/exercises/domain/seed_sync.dart';

Exercise _builtin(String id, {int rev = 1, String? name}) => Exercise(
  id: id,
  name: name ?? 'Ćwiczenie $id',
  source: ExerciseSource.builtin,
  seedVersion: rev,
);

void main() {
  test('nowe pozycje są dodawane', () {
    final plan = planSeedSync(
      existing: [],
      seed: [_builtin('a'), _builtin('b')],
    );

    expect([for (final e in plan.inserts) e.id], ['a', 'b']);
    expect(plan.updates, isEmpty);
  });

  test('pozycja z nowszą rewizją jest aktualizowana, z tą samą pomijana', () {
    final plan = planSeedSync(
      existing: [_builtin('a'), _builtin('b')],
      seed: [
        _builtin('a', rev: 2, name: 'Nowa nazwa'),
        _builtin('b'),
      ],
    );

    expect(plan.inserts, isEmpty);
    expect(plan.updates.single.name, 'Nowa nazwa');
  });

  test(
    'ćwiczenie zmodyfikowane przez użytkownika nigdy nie jest nadpisywane',
    () {
      final plan = planSeedSync(
        existing: [
          _builtin('a').copyWith(name: 'Moja nazwa', userModified: true),
        ],
        seed: [_builtin('a', rev: 5, name: 'Nazwa z seeda')],
      );

      expect(plan.isEmpty, isTrue);
      expect(plan.skippedUserModified, ['a']);
    },
  );

  test('aktualizacja zachowuje archiwizację', () {
    final archivedAt = DateTime.utc(2026, 10, 1);
    final plan = planSeedSync(
      existing: [_builtin('a').copyWith(archivedAt: archivedAt)],
      seed: [_builtin('a', rev: 2)],
    );

    expect(plan.updates.single.archivedAt, archivedAt);
  });

  test('pozycje usunięte z seeda zostają w bazie', () {
    final plan = planSeedSync(existing: [_builtin('old')], seed: []);

    expect(plan.isEmpty, isTrue);
  });
}
