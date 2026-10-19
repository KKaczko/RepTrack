import 'package:flutter_test/flutter_test.dart';
import 'package:reptrack/features/exercises/domain/exercise.dart';
import 'package:reptrack/features/progress/domain/metrics.dart';
import 'package:reptrack/features/workout/domain/session_builder.dart';
import 'package:reptrack/features/workout/domain/session_editing.dart';
import 'package:reptrack/features/workout/domain/session_summary.dart';
import 'package:reptrack/features/workout/domain/workout_session.dart';

import '../../../support/fakes.dart';
import '../../../support/workout_fixtures.dart';

final _start = DateTime.utc(2026, 10, 19, 16);

/// Trening z szablonu z zatwierdzonymi seriami ławki (bez rozgrzewki).
WorkoutSession _session(List<(int, int)> benchSets) {
  var session = buildSessionFromTemplate(
    template: pushTemplate(),
    exercises: catalog,
    ids: SequentialIds('s'),
    startedAt: _start,
    timeZone: 'Europe/Warsaw',
  );
  final benchEx = sortedExercises(session).first;
  for (final (i, (weight, reps)) in benchSets.indexed) {
    session = updateSet(
      session,
      benchEx.id,
      sortedSets(benchEx)[i + 1].id,
      (s) => s.copyWith(weightG: weight, reps: reps, completedAt: _start),
    );
  }
  return session;
}

PerformedSet _performed(int weight, int reps) => (
  set: SessionSet(
    id: 'h',
    position: 0,
    weightG: weight,
    reps: reps,
    completedAt: _start,
  ),
  loadMode: LoadMode.external,
);

void main() {
  test('podsumowanie: czas, serie, ćwiczenia, objętość bez rozgrzewek', () {
    final session = _session([(80000, 10), (80000, 8)]);

    final summary = summarizeSession(
      session,
      _start.add(const Duration(minutes: 47)),
    );

    expect(summary.duration, const Duration(minutes: 47));
    expect(summary.completedSets, 2);
    expect(summary.exercisesDone, 1);
    expect(summary.volumeG, 80000 * 18);
    // 4 serie ławki + 3 podciągania, 2 zatwierdzone.
    expect(openSetCount(session), 5);
  });

  test('rekordy względem historii z nazwą ćwiczenia', () {
    final session = _session([(85000, 8)]);

    final records = sessionRecords(session, {
      'bench': [_performed(80000, 8)],
    });

    expect(records.map((r) => r.exerciseName).toSet(), {'Wyciskanie'});
    expect(records.map((r) => r.event).whereType<E1rmRecord>(), hasLength(1));
    final repsWeight = records
        .map((r) => r.event)
        .whereType<RepsWeightRecord>()
        .single;
    expect((repsWeight.reps, repsWeight.weightG), (8, 85000));
  });

  test('bez historii nie ma rekordów', () {
    expect(sessionRecords(_session([(85000, 8)]), const {}), isEmpty);
  });
}
