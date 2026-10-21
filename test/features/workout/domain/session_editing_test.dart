import 'package:flutter_test/flutter_test.dart';
import 'package:reptrack/core/domain/training.dart';
import 'package:reptrack/features/exercises/domain/exercise.dart';
import 'package:reptrack/features/workout/domain/rest_timer.dart';
import 'package:reptrack/features/workout/domain/session_builder.dart';
import 'package:reptrack/features/workout/domain/session_editing.dart';
import 'package:reptrack/features/workout/domain/session_summary.dart';
import 'package:reptrack/features/workout/domain/workout_session.dart';

import '../../../support/fakes.dart';
import '../../../support/workout_fixtures.dart';

WorkoutSession _session() => buildSessionFromTemplate(
  template: pushTemplate(),
  exercises: catalog,
  ids: SequentialIds('s'),
  startedAt: DateTime.utc(2026, 10, 19, 16),
  timeZone: 'Europe/Warsaw',
);

void main() {
  test('dodana seria kopiuje plan ostatniej i jest pusta', () {
    final session = _session();
    final benchId = session.exercises.first.id;

    final result = addSet(session, benchId, SequentialIds('n'));
    final sets = sortedSets(result.exercises.first);

    expect(sets, hasLength(5));
    expect(sets.last.position, 4);
    expect((sets.last.targetMin, sets.last.targetMax), (8, 12));
    expect(sets.last.targetWeightG, 80000);
    expect(sets.last.weightG, isNull);
  });

  test('usunięcie serii przenumerowuje', () {
    final session = _session();
    final bench = session.exercises.first;

    final result = removeSet(session, bench.id, bench.sets[1].id);

    expect(
      [for (final s in sortedSets(result.exercises.first)) s.position],
      [0, 1, 2],
    );
  });

  test('dodanie, usunięcie i przeniesienie ćwiczeń', () {
    var session = addExercisesToSession(_session(), [
      plank,
      run,
    ], SequentialIds('x'));
    expect(
      [for (final e in sortedExercises(session)) e.exerciseId],
      ['bench', 'pullup', 'plank', 'run'],
    );

    session = moveExerciseInSession(session, 3, 0);
    expect(sortedExercises(session).first.exerciseId, 'run');

    session = removeExerciseFromSession(
      session,
      sortedExercises(session)[1].id,
    );
    expect(
      [for (final e in sortedExercises(session)) e.exerciseId],
      ['run', 'pullup', 'plank'],
    );
    expect([for (final e in sortedExercises(session)) e.position], [0, 1, 2]);
  });

  test('zamiana ćwiczenia: nowy snapshot, plan zostaje, wartości znikają', () {
    var session = _session();
    final benchEx = session.exercises.first;
    session = updateSet(
      session,
      benchEx.id,
      benchEx.sets.first.id,
      (s) => s.copyWith(
        weightG: 40000,
        reps: 10,
        completedAt: DateTime.utc(2026, 10, 19, 16, 5),
      ),
    );

    const dbPress = Exercise(
      id: 'db',
      name: 'Hantle',
      equipment: Equipment.dumbbell,
    );
    final result = replaceExerciseInSession(session, benchEx.id, dbPress);
    final replaced = result.exercises.first;

    expect(replaced.id, benchEx.id);
    expect(replaced.exerciseId, 'db');
    expect(replaced.exerciseNameSnapshot, 'Hantle');
    expect(replaced.templateExerciseId, 'te-bench');
    expect(replaced.sets.first.setType, SetType.warmup);
    expect(replaced.sets.first.isCompleted, isFalse);
    expect(replaced.sets.first.weightG, isNull);
  });

  group('przerwa', () {
    final now = DateTime.utc(2026, 10, 19, 17);

    test('z planu albo domyślna', () {
      expect(
        restAfter(const SessionSet(id: 's', position: 0, restSeconds: 150), 90),
        const Duration(seconds: 150),
      );
      expect(
        restAfter(const SessionSet(id: 's', position: 0), 90),
        const Duration(seconds: 90),
      );
    });

    test('±15 s i koniec przerwy', () {
      final end = now.add(const Duration(seconds: 20));

      expect(adjustRestEnd(end, now, restAdjustStep), end.add(restAdjustStep));
      expect(
        adjustRestEnd(end, now, -restAdjustStep),
        end.subtract(restAdjustStep),
      );
      expect(adjustRestEnd(end, now, const Duration(seconds: -30)), isNull);
      expect(adjustRestEnd(null, now, restAdjustStep), isNull);
      expect(restRemaining(end, now), const Duration(seconds: 20));
      expect(restRemaining(now.subtract(restAdjustStep), now), Duration.zero);
    });
  });

  test('podsumowanie: czas, serie, objętość bez rozgrzewek', () {
    var session = _session();
    final benchEx = session.exercises.first;
    final done = DateTime.utc(2026, 10, 19, 16, 10);
    for (final (i, set) in sortedSets(benchEx).take(3).indexed) {
      session = updateSet(
        session,
        benchEx.id,
        set.id,
        (s) => s.copyWith(
          weightG: i == 0 ? 40000 : 80000,
          reps: 10,
          completedAt: done,
        ),
      );
    }

    final summary = summarizeSession(session, DateTime.utc(2026, 10, 19, 17));

    expect(summary.duration, const Duration(hours: 1));
    expect(summary.completedSets, 3);
    expect(summary.exercisesDone, 1);
    expect(summary.volumeG, 2 * 80000 * 10);
  });

  test('rozgrzewka na początku ćwiczenia i cofnięcie', () {
    final session = buildSessionFromTemplate(
      template: pushTemplate(),
      exercises: catalog,
      ids: SequentialIds('s'),
      startedAt: DateTime.utc(2026, 10, 19, 16),
      timeZone: 'Europe/Warsaw',
    );
    final bench = sortedExercises(session).first;
    final before = sortedSets(bench);

    final result = addWarmupSets(session, bench.id, const [
      (weightG: 40000, reps: 8),
      (weightG: 60000, reps: 5),
    ], SequentialIds('w'));

    final sets = sortedSets(sortedExercises(result.session).first);
    expect(sets.map((s) => s.position), List.generate(sets.length, (i) => i));
    expect(sets.take(2).map((s) => (s.setType, s.targetWeightG, s.targetMin)), [
      (SetType.warmup, 40000, 8),
      (SetType.warmup, 60000, 5),
    ]);
    expect(sets.skip(2).map((s) => s.id), before.map((s) => s.id));

    final undone = removeSets(result.session, bench.id, result.setIds.toSet());
    expect(
      sortedSets(sortedExercises(undone).first).map((s) => s.id),
      before.map((s) => s.id),
    );
  });
}
