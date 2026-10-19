import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reptrack/core/database/app_database.dart';
import 'package:reptrack/core/domain/local_date.dart';
import 'package:reptrack/features/exercises/domain/exercise.dart';
import 'package:reptrack/features/workout/domain/workout_session.dart';

import '../../support/test_database.dart';

WorkoutSessionsCompanion _session(String id, SessionStatus status) {
  final now = DateTime.utc(2026, 10, 19, 18);
  return WorkoutSessionsCompanion.insert(
    id: id,
    createdAt: now,
    updatedAt: now,
    status: status,
    startedAt: now,
    timeZone: 'Europe/Warsaw',
    localDate: const LocalDate(2026, 10, 19),
  );
}

void main() {
  late AppDatabase db;

  setUp(() => db = memoryDatabase());
  tearDown(() => db.close());

  test('klucze obce są włączone', () async {
    final row = await db.customSelect('PRAGMA foreign_keys').getSingle();

    expect(row.read<int>('foreign_keys'), 1);
  });

  test('indeks dopuszcza najwyżej jedną aktywną sesję', () async {
    await db
        .into(db.workoutSessions)
        .insert(_session('a', SessionStatus.active));
    await db
        .into(db.workoutSessions)
        .insert(_session('b', SessionStatus.completed));

    await expectLater(
      db.into(db.workoutSessions).insert(_session('c', SessionStatus.active)),
      throwsA(isA<Exception>()),
    );
  });

  test('miękko usunięta aktywna sesja nie blokuje nowej', () async {
    await db
        .into(db.workoutSessions)
        .insert(
          _session(
            'a',
            SessionStatus.active,
          ).copyWith(deletedAt: Value(DateTime.utc(2026, 10, 19, 19))),
        );

    await db
        .into(db.workoutSessions)
        .insert(_session('b', SessionStatus.active));
  });

  test('ćwiczenie musi mierzyć co najmniej jedno pole', () async {
    final now = DateTime.utc(2026, 10, 19);

    await expectLater(
      db
          .into(db.exercises)
          .insert(
            ExercisesCompanion.insert(
              id: 'x',
              createdAt: now,
              updatedAt: now,
              name: 'Bez pomiaru',
              aliases: const [],
              searchText: 'bez pomiaru',
              primaryMuscles: const [],
              secondaryMuscles: const [],
              category: ExerciseCategory.strength,
              measureWeight: false,
              measureReps: false,
              measureDuration: false,
              measureDistance: false,
              loadMode: LoadMode.external,
              weightSemantics: WeightSemantics.total,
              isUnilateral: false,
              source: ExerciseSource.user,
              userModified: false,
            ),
          ),
      throwsA(isA<Exception>()),
    );
  });

  test('samopoczucie poza skalą 1–5 jest odrzucane', () async {
    await expectLater(
      db
          .into(db.workoutSessions)
          .insert(
            _session(
              'a',
              SessionStatus.completed,
            ).copyWith(wellbeing: const Value(6)),
          ),
      throwsA(isA<Exception>()),
    );
  });
}
