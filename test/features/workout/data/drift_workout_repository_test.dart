import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:reptrack/core/database/app_database.dart';
import 'package:reptrack/core/domain/clock.dart';
import 'package:reptrack/core/domain/local_date.dart';
import 'package:reptrack/core/domain/training.dart';
import 'package:reptrack/features/exercises/data/drift_exercise_repository.dart';
import 'package:reptrack/features/exercises/domain/exercise.dart';
import 'package:reptrack/features/workout/data/drift_workout_repository.dart';
import 'package:reptrack/features/workout/domain/workout_repository.dart';
import 'package:reptrack/features/workout/domain/workout_session.dart';

import '../../../support/test_database.dart';

WorkoutSession _session(
  String id, {
  SessionStatus status = SessionStatus.active,
}) => WorkoutSession(
  id: id,
  status: status,
  startedAt: DateTime.utc(2026, 10, 19, 17),
  timeZone: 'Europe/Warsaw',
  localDate: const LocalDate(2026, 10, 19),
  title: 'Pusty trening',
  restEndsAt: DateTime.utc(2026, 10, 19, 17, 32),
  exercises: [
    SessionExercise(
      id: '$id-se',
      exerciseId: 'bench',
      position: 0,
      exerciseNameSnapshot: 'Wyciskanie na ławce',
      measurementSnapshot: Measurement.weightAndReps,
      loadModeSnapshot: LoadMode.external,
      weightSemanticsSnapshot: WeightSemantics.total,
      isUnilateralSnapshot: false,
      sets: [
        SessionSet(
          id: '$id-s0',
          position: 0,
          targetKind: TargetKind.reps,
          targetMin: 8,
          targetMax: 12,
          weightG: 80000,
          reps: 10,
          effortScale: EffortScale.rir,
          effortTenths: 20,
          completedAt: DateTime.utc(2026, 10, 19, 17, 30),
        ),
        SessionSet(
          id: '$id-s1',
          position: 1,
          targetKind: TargetKind.reps,
          targetMin: 8,
          targetMax: 12,
        ),
      ],
    ),
  ],
);

void main() {
  late AppDatabase db;
  late FixedClock clock;
  late DriftWorkoutRepository repo;

  Future<void> seedExercises(AppDatabase target) async {
    await DriftExerciseRepository(target, clock).save(testExercise('bench'));
  }

  setUp(() async {
    db = memoryDatabase();
    clock = testClock();
    repo = DriftWorkoutRepository(db, clock);
    await seedExercises(db);
  });
  tearDown(() => db.close());

  test('zapis i odczyt aktywnej sesji', () async {
    await repo.save(_session('w1'));

    final active = await repo.findActive();

    expect(active, _session('w1'));
    expect(active!.exercises.single.sets.first.isCompleted, isTrue);
    expect(active.exercises.single.sets.last.isCompleted, isFalse);
  });

  test('druga aktywna sesja jest odrzucana', () async {
    await repo.save(_session('w1'));

    await expectLater(
      repo.save(_session('w2')),
      throwsA(isA<ActiveSessionExistsException>()),
    );
    await repo.save(_session('w2', status: SessionStatus.completed));
    expect((await repo.findActive())!.id, 'w1');
  });

  test('usunięta seria znika z sesji', () async {
    await repo.save(_session('w1'));
    final session = _session('w1');
    final exercise = session.exercises.single;

    await repo.save(
      session.copyWith(
        exercises: [
          exercise.copyWith(sets: [exercise.sets.first]),
        ],
      ),
    );

    expect((await repo.findById('w1'))!.exercises.single.sets, hasLength(1));
  });

  test('watchActive emituje po zatwierdzeniu serii', () async {
    await repo.save(_session('w1'));
    final completed = <int>[];
    final sub = repo.watchActive().listen(
      (s) => completed.add(
        s!.exercises.single.sets.where((set) => set.isCompleted).length,
      ),
    );
    await pumpEventQueue();

    final session = _session('w1');
    final exercise = session.exercises.single;
    await repo.save(
      session.copyWith(
        exercises: [
          exercise.copyWith(
            sets: [
              exercise.sets.first,
              exercise.sets.last.copyWith(
                weightG: 80000,
                reps: 9,
                completedAt: DateTime.utc(2026, 10, 19, 17, 34),
              ),
            ],
          ),
        ],
      ),
    );
    await pumpEventQueue();
    await sub.cancel();

    expect(completed.first, 1);
    expect(completed.last, 2);
  });

  test('aktywna sesja przetrwa zamknięcie i ponowne otwarcie bazy', () async {
    final dir = await Directory.systemTemp.createTemp('reptrack_test_');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/reptrack.sqlite');

    // Pierwszy „proces”: zapis i nagłe zamknięcie.
    final first = fileDatabase(file);
    await seedExercises(first);
    await DriftWorkoutRepository(first, clock).save(_session('w1'));
    await first.close();

    // Drugi „proces”: nowa instancja bazy na tym samym pliku.
    final second = fileDatabase(file);
    addTearDown(second.close);
    final restored = await DriftWorkoutRepository(second, clock).findActive();

    expect(restored, _session('w1'));
    expect(restored!.restEndsAt, DateTime.utc(2026, 10, 19, 17, 32));
  });
}
