import 'package:flutter_test/flutter_test.dart';
import 'package:reptrack/core/database/app_database.dart';
import 'package:reptrack/core/domain/clock.dart';
import 'package:reptrack/core/domain/training.dart';
import 'package:reptrack/features/exercises/data/drift_exercise_repository.dart';
import 'package:reptrack/features/exercises/domain/exercise.dart';
import 'package:reptrack/features/templates/data/drift_template_repository.dart';
import 'package:reptrack/features/templates/domain/set_plan.dart';
import 'package:reptrack/features/workout/data/drift_workout_repository.dart';
import 'package:reptrack/features/workout/domain/session_builder.dart';
import 'package:reptrack/features/workout/domain/session_editing.dart';
import 'package:reptrack/features/workout/domain/workout_session.dart';

import '../../../support/fakes.dart';
import '../../../support/test_database.dart';
import '../../../support/workout_fixtures.dart';

void main() {
  late AppDatabase db;
  late FixedClock clock;
  late DriftWorkoutRepository workouts;
  late DriftTemplateRepository templates;
  late DriftExerciseRepository exercises;

  setUp(() async {
    db = memoryDatabase();
    clock = testClock();
    workouts = DriftWorkoutRepository(db, clock);
    templates = DriftTemplateRepository(db, clock);
    exercises = DriftExerciseRepository(db, clock);
    for (final e in catalog.values) {
      await exercises.save(e);
    }
    await templates.save(pushTemplate());
  });
  tearDown(() => db.close());

  /// Zakończona sesja z szablonu z zatwierdzonymi seriami ławki.
  Future<WorkoutSession> finishedSession(
    String prefix,
    DateTime start,
    List<(int, int)> benchSets,
  ) async {
    var session = buildSessionFromTemplate(
      template: pushTemplate(),
      exercises: catalog,
      ids: SequentialIds(prefix),
      startedAt: start,
      timeZone: 'Europe/Warsaw',
    );
    final benchEx = sortedExercises(session).first;
    for (final (i, (weight, reps)) in benchSets.indexed) {
      final set = sortedSets(benchEx)[i + 1]; // pomijamy rozgrzewkę
      session = updateSet(
        session,
        benchEx.id,
        set.id,
        (s) => s.copyWith(
          weightG: weight,
          reps: reps,
          completedAt: start.add(const Duration(minutes: 10)),
        ),
      );
    }
    session = session.copyWith(
      status: SessionStatus.completed,
      endedAt: start.add(const Duration(hours: 1)),
    );
    await workouts.save(session);
    return session;
  }

  test(
    'poprzednie wykonanie: ostatnia zakończona sesja z ćwiczeniem',
    () async {
      await finishedSession('a', DateTime.utc(2026, 10, 5, 16), [
        (75000, 10),
        (75000, 9),
      ]);
      await finishedSession('b', DateTime.utc(2026, 10, 12, 16), [
        (80000, 10),
        (80000, 8),
      ]);
      final active = buildEmptySession(
        ids: SequentialIds('c'),
        startedAt: DateTime.utc(2026, 10, 19, 16),
        timeZone: 'Europe/Warsaw',
      );
      await workouts.save(
        addExercisesToSession(active, [bench], SequentialIds('d')),
      );

      final previous = await workouts.lastCompletedSets(
        'bench',
        excludeSessionId: active.id,
      );

      expect(
        [for (final s in previous) (s.weightG, s.reps)],
        [(80000, 10), (80000, 8)],
      );
      expect(await workouts.lastCompletedSets('plank'), isEmpty);
    },
  );

  test('wystąpienie bez zatwierdzonych serii nie przesłania wyniku', () async {
    await finishedSession('a', DateTime.utc(2026, 10, 5, 16), [
      (75000, 10),
      (75000, 9),
    ]);
    // Nowszy trening z ławką, ale bez żadnej zatwierdzonej serii.
    await finishedSession('b', DateTime.utc(2026, 10, 12, 16), []);

    final previous = await workouts.lastCompletedSets('bench');

    expect(
      [for (final s in previous) (s.weightG, s.reps)],
      [(75000, 10), (75000, 9)],
    );
  });

  test('porzucona sesja nie jest poprzednim wykonaniem ani historią', () async {
    await finishedSession('a', DateTime.utc(2026, 10, 5, 16), [(75000, 10)]);
    final newer = await finishedSession('b', DateTime.utc(2026, 10, 12, 16), [
      (90000, 5),
    ]);

    await workouts.discard(newer.id);

    final previous = await workouts.lastCompletedSets('bench');
    expect(previous.single.weightG, 75000);
    expect(await workouts.findById(newer.id), isNull);
    final performed = await workouts.completedSetsFor({'bench'});
    expect(performed['bench'], hasLength(1));
  });

  test('serie do rekordów z trybem obciążenia z chwili wykonania', () async {
    await finishedSession('a', DateTime.utc(2026, 10, 5, 16), [
      (75000, 10),
      (80000, 8),
    ]);

    final performed = await workouts.completedSetsFor({'bench', 'pullup'});

    expect(performed['bench'], hasLength(2));
    expect(
      performed['bench']!.every((p) => p.loadMode == LoadMode.external),
      isTrue,
    );
    expect(performed.containsKey('pullup'), isFalse);
  });

  test('zmiany szablonu i ćwiczenia nie zmieniają zapisanej sesji', () async {
    final saved = await finishedSession('a', DateTime.utc(2026, 10, 5, 16), [
      (75000, 10),
    ]);
    final before = await workouts.findById(saved.id);

    // Zmiana szablonu: inny cel, więcej serii, usunięte ćwiczenie.
    final template = (await templates.findById('tpl'))!;
    await templates.save(
      template.copyWith(
        name: 'Push B',
        exercises: [
          withSetCount(
            template.exercises.first.copyWith(targetMin: 3, targetMax: 5),
            6,
            SequentialIds('x'),
          ),
        ],
      ),
    );
    // Zmiana ćwiczenia: nazwa, pomiar, tryb obciążenia, archiwizacja.
    await exercises.save(
      bench.copyWith(
        name: 'Nowa nazwa',
        measurement: Measurement.repsOnly,
        loadMode: LoadMode.bodyweight,
        userModified: true,
      ),
    );
    await exercises.setArchived('bench', archived: true);

    final after = await workouts.findById(saved.id);
    expect(after, before);
    final benchEx = sortedExercises(after!).first;
    expect(benchEx.exerciseNameSnapshot, 'Wyciskanie');
    expect(benchEx.measurementSnapshot, Measurement.weightAndReps);
    expect(benchEx.loadModeSnapshot, LoadMode.external);
    expect(after.templateNameSnapshot, 'Push A');
    expect(sortedSets(benchEx), hasLength(4));
    expect(
      (sortedSets(benchEx)[1].targetMin, sortedSets(benchEx)[1].targetMax),
      (8, 12),
    );
    expect(sortedSets(benchEx).first.setType, SetType.warmup);
  });

  test('cofnięcie zatwierdzenia i koniec przerwy zapisują null', () async {
    final session = await finishedSession('a', DateTime.utc(2026, 10, 5, 16), [
      (75000, 10),
    ]);
    final benchEx = sortedExercises(session).first;
    final done = sortedSets(benchEx)[1];
    await workouts.save(
      updateSet(
        session.copyWith(
          status: SessionStatus.active,
          endedAt: null,
          notes: null,
          restEndsAt: null,
        ),
        benchEx.id,
        done.id,
        (s) => s.copyWith(completedAt: null, weightG: null),
      ),
    );

    final reloaded = (await workouts.findById(session.id))!;
    final set = sortedSets(sortedExercises(reloaded).first)[1];
    expect(set.completedAt, isNull);
    expect(set.weightG, isNull);
    expect(reloaded.endedAt, isNull);
    expect(reloaded.status, SessionStatus.active);
  });

  test(
    'historia odświeża się tylko po zmianach zakończonych treningów',
    () async {
      final emissions = <List<String>>[];
      final sub = workouts.watchCompleted().listen(
        (list) => emissions.add([for (final s in list) s.id]),
      );
      addTearDown(sub.cancel);
      await pumpEventQueue();
      expect(emissions, [<String>[]]);

      // Aktywny trening: każdy zapis to zmiana tabel, ale nie historii.
      var active = buildSessionFromTemplate(
        template: pushTemplate(),
        exercises: catalog,
        ids: SequentialIds('act'),
        startedAt: DateTime.utc(2026, 10, 19, 16),
        timeZone: 'Europe/Warsaw',
      );
      await workouts.save(active);
      final benchEx = sortedExercises(active).first;
      active = updateSet(
        active,
        benchEx.id,
        sortedSets(benchEx)[1].id,
        (s) => s.copyWith(weightG: 80000, reps: 8, completedAt: clock.nowUtc()),
      );
      await workouts.save(active);
      await pumpEventQueue();
      expect(emissions, hasLength(1));

      // Zakończenie, korekta i usunięcie zmieniają historię.
      final finished = active.copyWith(
        status: SessionStatus.completed,
        endedAt: DateTime.utc(2026, 10, 19, 17),
      );
      await workouts.save(finished);
      await pumpEventQueue();
      expect(emissions.last, [active.id]);

      clock.advance(const Duration(minutes: 1));
      await workouts.save(
        updateSet(
          finished,
          benchEx.id,
          sortedSets(benchEx)[1].id,
          (s) => s.copyWith(reps: 9),
        ),
      );
      await pumpEventQueue();
      expect(emissions, hasLength(3));
      final edited = (await workouts.watchCompleted().first).single;
      expect(sortedSets(sortedExercises(edited).first)[1].reps, 9);

      await workouts.delete(active.id);
      await pumpEventQueue();
      expect(emissions.last, isEmpty);
    },
  );
}
