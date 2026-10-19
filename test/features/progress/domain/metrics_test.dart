import 'package:flutter_test/flutter_test.dart';
import 'package:reptrack/core/domain/training.dart';
import 'package:reptrack/features/exercises/domain/exercise.dart';
import 'package:reptrack/features/progress/domain/metrics.dart';
import 'package:reptrack/features/workout/domain/workout_session.dart';

final _at = DateTime.utc(2026, 10, 19);

PerformedSet _set(
  int? weightG,
  int reps, {
  SetType type = SetType.working,
  LoadMode mode = LoadMode.external,
  bool completed = true,
}) => (
  set: SessionSet(
    id: 's',
    position: 0,
    setType: type,
    weightG: weightG,
    reps: reps,
    completedAt: completed ? _at : null,
  ),
  loadMode: mode,
);

void main() {
  group('szacowany 1RM (Epley)', () {
    test('wzór dla 2–10 powtórzeń', () {
      expect(estimatedOneRepMax(100000, 10), closeTo(133333.3, 0.1));
      expect(estimatedOneRepMax(100000, 5), closeTo(116666.7, 0.1));
    });

    test('1 powtórzenie to sam ciężar', () {
      expect(estimatedOneRepMax(100000, 1), 100000);
    });

    test('ponad 10 powtórzeń i brak ciężaru: brak szacunku', () {
      expect(estimatedOneRepMax(60000, 11), isNull);
      expect(estimatedOneRepMax(0, 5), isNull);
      expect(estimatedOneRepMax(60000, 0), isNull);
    });
  });

  group('objętość', () {
    test('ciężar × powtórzenia, bez rozgrzewek i niezatwierdzonych', () {
      expect(setVolumeG(_set(80000, 10).set, LoadMode.external), 800000);
      expect(
        setVolumeG(
          _set(40000, 10, type: SetType.warmup).set,
          LoadMode.external,
        ),
        0,
      );
      expect(
        setVolumeG(_set(80000, 10, completed: false).set, LoadMode.external),
        0,
      );
    });

    test('masa ciała i wspomaganie nie dają objętości ciężaru', () {
      expect(setVolumeG(_set(0, 15).set, LoadMode.bodyweight), 0);
      expect(setVolumeG(_set(20000, 8).set, LoadMode.assisted), 0);
      expect(
        setVolumeG(_set(10000, 8).set, LoadMode.weightedBodyweight),
        80000,
      );
    });
  });

  group('rekordy', () {
    test('najlepszy e1RM i najcięższa seria dla co najmniej N powt.', () {
      final records = computeRecords([
        _set(100000, 5),
        _set(90000, 8),
        _set(120000, 1),
        _set(60000, 12, type: SetType.warmup),
      ]);

      expect(records.bestE1rmG, closeTo(120000, 0.1));
      expect(records.bestWeightForReps[1], 120000);
      expect(records.bestWeightForReps[3], 100000);
      expect(records.bestWeightForReps[5], 100000);
      expect(records.bestWeightForReps[8], 90000);
      expect(records.bestWeightForReps.containsKey(9), isFalse);
    });

    test('masa ciała: rekord powtórzeń', () {
      final records = computeRecords([
        _set(null, 15, mode: LoadMode.bodyweight),
        _set(null, 20, mode: LoadMode.bodyweight),
      ]);

      expect(records.maxReps, 20);
      expect(records.bestE1rmG, isNull);
    });

    test(
      'nowe rekordy względem historii; pierwszy trening nie jest rekordem',
      () {
        final before = computeRecords([_set(100000, 5), _set(80000, 10)]);
        final session = computeRecords([_set(105000, 5), _set(80000, 8)]);

        final events = newRecords(before: before, session: session);

        expect(events.whereType<E1rmRecord>().single.e1rmG, closeTo(122500, 1));
        final repsRecord = events.whereType<RepsWeightRecord>().single;
        expect((repsRecord.reps, repsRecord.weightG), (5, 105000));
        expect(
          newRecords(before: const ExerciseRecords(), session: session),
          isEmpty,
        );
      },
    );
  });
}
