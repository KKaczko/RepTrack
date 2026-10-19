import 'package:flutter_test/flutter_test.dart';
import 'package:reptrack/core/domain/local_date.dart';
import 'package:reptrack/core/domain/training.dart';
import 'package:reptrack/features/exercises/domain/exercise.dart';
import 'package:reptrack/features/workout/domain/set_hints.dart';
import 'package:reptrack/features/workout/domain/workout_session.dart';

final _done = DateTime.utc(2026, 10, 12, 17);

SessionSet _prev(
  int position,
  int weightG,
  int reps, {
  SetType type = SetType.working,
  bool completed = true,
}) => SessionSet(
  id: 'p$position',
  position: position,
  setType: type,
  weightG: weightG,
  reps: reps,
  completedAt: completed ? _done : null,
);

void main() {
  group('matchPreviousSets', () {
    test('robocze po kolejności wśród roboczych, rozgrzewki osobno', () {
      final previous = [
        _prev(0, 40000, 10, type: SetType.warmup),
        _prev(1, 80000, 10),
        _prev(2, 80000, 9),
      ];
      // Dziś: dwie rozgrzewki, potem trzy robocze.
      final current = [
        const SessionSet(id: 'w1', position: 0, setType: SetType.warmup),
        const SessionSet(id: 'w2', position: 1, setType: SetType.warmup),
        const SessionSet(id: 'a', position: 2),
        const SessionSet(id: 'b', position: 3),
        const SessionSet(id: 'c', position: 4),
      ];

      final matched = matchPreviousSets(current, previous);

      expect(matched['w1']!.id, 'p0');
      expect(matched.containsKey('w2'), isFalse);
      expect(matched['a']!.id, 'p1');
      expect(matched['b']!.id, 'p2');
      expect(matched.containsKey('c'), isFalse);
    });

    test('pomija niezatwierdzone serie poprzedniego treningu', () {
      final previous = [
        _prev(0, 80000, 10, completed: false),
        _prev(1, 85000, 8),
      ];

      final matched = matchPreviousSets([
        const SessionSet(id: 'a', position: 0),
      ], previous);

      expect(matched['a']!.id, 'p1');
    });
  });

  group('hintForSet', () {
    const planned = SessionSet(
      id: 's',
      position: 0,
      targetKind: TargetKind.reps,
      targetMin: 8,
      targetMax: 12,
      targetWeightG: 75000,
    );

    test('kolejność źródeł: wpisane → poprzednie → plan', () {
      final fromPrevious = hintForSet(
        set: planned,
        previous: _prev(0, 80000, 10),
        measurement: Measurement.weightAndReps,
        loadMode: LoadMode.external,
      );
      expect(fromPrevious.weightG, (value: 80000, source: HintSource.previous));
      expect(fromPrevious.reps, (value: 10, source: HintSource.previous));

      final fromPlan = hintForSet(
        set: planned,
        previous: null,
        measurement: Measurement.weightAndReps,
        loadMode: LoadMode.external,
      );
      expect(fromPlan.weightG, (value: 75000, source: HintSource.plan));
      expect(fromPlan.reps, (value: 8, source: HintSource.plan));

      final entered = hintForSet(
        set: planned.copyWith(weightG: 82500),
        previous: _prev(0, 80000, 10),
        measurement: Measurement.weightAndReps,
        loadMode: LoadMode.external,
      );
      expect(entered.weightG, (value: 82500, source: HintSource.entered));
      expect(entered.reps!.source, HintSource.previous);
    });

    test('dociążenie i wspomaganie: brak ciężaru oznacza 0', () {
      final hint = hintForSet(
        set: const SessionSet(id: 's', position: 0),
        previous: null,
        measurement: Measurement.weightAndReps,
        loadMode: LoadMode.weightedBodyweight,
      );

      expect(hint.weightG, (value: 0, source: HintSource.plan));
      expect(hint.reps, isNull);
      expect(hint.isComplete(Measurement.weightAndReps), isFalse);
    });

    test('cel czasowy podpowiada czas, a dystans tylko z historii', () {
      final hint = hintForSet(
        set: const SessionSet(
          id: 's',
          position: 0,
          targetKind: TargetKind.duration,
          targetMin: 30,
          targetMax: 60,
        ),
        previous: null,
        measurement: const Measurement(duration: true, distance: true),
        loadMode: LoadMode.bodyweight,
      );

      expect(hint.durationS, (value: 30, source: HintSource.plan));
      expect(hint.distanceM, isNull);
      expect(hint.weightG, isNull);
    });
  });

  group('confirmSet', () {
    final now = DateTime.utc(2026, 10, 19, 17, 5);

    test('podpowiedź nigdy sama nie zatwierdza serii', () {
      const set = SessionSet(id: 's', position: 0);

      final hint = hintForSet(
        set: set,
        previous: _prev(0, 80000, 10),
        measurement: Measurement.weightAndReps,
        loadMode: LoadMode.external,
      );

      expect(hint.isComplete(Measurement.weightAndReps), isTrue);
      expect(set.isCompleted, isFalse);
      expect(set.weightG, isNull);
    });

    test('zatwierdzenie kopiuje podpowiedzi i ustawia completedAt', () {
      const set = SessionSet(id: 's', position: 0, reps: 12);
      final hint = hintForSet(
        set: set,
        previous: _prev(0, 80000, 10),
        measurement: Measurement.weightAndReps,
        loadMode: LoadMode.external,
      );

      final confirmed = confirmSet(set, hint, Measurement.weightAndReps, now);

      expect(confirmed.weightG, 80000);
      expect(confirmed.reps, 12, reason: 'wpisana wartość wygrywa');
      expect(confirmed.completedAt, now);
      expect(uncompleteSet(confirmed).isCompleted, isFalse);
      expect(uncompleteSet(confirmed).weightG, 80000);
    });

    test('bez kompletu wartości zatwierdzenie jest odrzucane', () {
      const set = SessionSet(id: 's', position: 0);
      final hint = hintForSet(
        set: set,
        previous: null,
        measurement: Measurement.weightAndReps,
        loadMode: LoadMode.external,
      );

      expect(
        () => confirmSet(set, hint, Measurement.weightAndReps, now),
        throwsA(isA<IncompleteSetException>()),
      );
    });
  });

  test('nextOpenSet wskazuje pierwszą niezatwierdzoną serię', () {
    final exercise = SessionExercise(
      id: 'e',
      exerciseId: 'bench',
      position: 0,
      exerciseNameSnapshot: 'Wyciskanie',
      measurementSnapshot: Measurement.weightAndReps,
      loadModeSnapshot: LoadMode.external,
      weightSemanticsSnapshot: WeightSemantics.total,
      isUnilateralSnapshot: false,
      sets: [
        SessionSet(id: 'b', position: 1, completedAt: _done),
        SessionSet(id: 'a', position: 0, completedAt: _done),
        const SessionSet(id: 'c', position: 2),
      ],
    );

    expect(nextOpenSet(exercise)!.id, 'c');
  });

  group('pola serii', () {
    test('pola mierzone w stałej kolejności', () {
      expect(measuredFields(Measurement.weightAndReps), [
        SetField.weight,
        SetField.reps,
      ]);
      expect(
        measuredFields(const Measurement(duration: true, distance: true)),
        [SetField.duration, SetField.distance],
      );
    });

    test('wpis i odczyt wartości pola', () {
      const set = SessionSet(id: 's', position: 0);
      final changed = withSetValue(set, SetField.reps, 8);
      expect(setValue(changed, SetField.reps), 8);
      expect(setValue(changed, SetField.weight), isNull);
      expect(withSetValue(changed, SetField.reps, null).reps, isNull);
    });

    test('brakujące pola to te bez wpisu i bez podpowiedzi', () {
      final hint = hintForSet(
        set: const SessionSet(
          id: 's',
          position: 0,
          targetKind: TargetKind.reps,
          targetMin: 8,
        ),
        previous: null,
        measurement: Measurement.weightAndReps,
        loadMode: LoadMode.external,
      );
      expect(missingFields(hint, Measurement.weightAndReps), [SetField.weight]);
    });
  });

  group('nextExerciseToDo', () {
    SessionExercise exercise(String id, int position, {required bool done}) =>
        SessionExercise(
          id: id,
          exerciseId: id,
          position: position,
          exerciseNameSnapshot: id,
          measurementSnapshot: Measurement.weightAndReps,
          loadModeSnapshot: LoadMode.external,
          weightSemanticsSnapshot: WeightSemantics.total,
          isUnilateralSnapshot: false,
          sets: [
            SessionSet(
              id: '$id-0',
              position: 0,
              completedAt: done ? _done : null,
            ),
          ],
        );

    WorkoutSession session(List<SessionExercise> exercises) => WorkoutSession(
      id: 'w',
      status: SessionStatus.active,
      startedAt: _done,
      timeZone: 'Europe/Warsaw',
      localDate: const LocalDate(2026, 10, 12),
      exercises: exercises,
    );

    test('najpierw bieżące, potem kolejne, na końcu pominięte', () {
      final s = session([
        exercise('a', 0, done: false),
        exercise('b', 1, done: true),
        exercise('c', 2, done: false),
      ]);
      expect(nextExerciseToDo(s, 'a')!.id, 'a');
      expect(nextExerciseToDo(s, 'b')!.id, 'c');
      expect(nextExerciseToDo(s, 'c')!.id, 'c');
      expect(
        nextExerciseToDo(
          session([
            exercise('a', 0, done: false),
            exercise('b', 1, done: true),
          ]),
          'b',
        )!.id,
        'a',
      );
    });

    test('null, gdy wszystko zatwierdzone', () {
      expect(
        nextExerciseToDo(session([exercise('a', 0, done: true)]), 'a'),
        isNull,
      );
    });
  });

  test('wcześniejsza seria tego treningu uzupełnia brak podpowiedzi', () {
    final exercise = SessionExercise(
      id: 'e',
      exerciseId: 'db',
      position: 0,
      exerciseNameSnapshot: 'Hantle',
      measurementSnapshot: Measurement.weightAndReps,
      loadModeSnapshot: LoadMode.external,
      weightSemanticsSnapshot: WeightSemantics.total,
      isUnilateralSnapshot: false,
      sets: [
        const SessionSet(
          id: 'w',
          position: 0,
          setType: SetType.warmup,
          weightG: 10000,
          reps: 12,
        ),
        SessionSet(
          id: 'a',
          position: 1,
          weightG: 22500,
          reps: 8,
          targetKind: TargetKind.reps,
          targetMin: 8,
          completedAt: _done,
        ),
        const SessionSet(
          id: 'b',
          position: 2,
          targetKind: TargetKind.reps,
          targetMin: 8,
        ),
        const SessionSet(
          id: 'c',
          position: 3,
          targetKind: TargetKind.reps,
          targetMin: 8,
          reps: 10,
        ),
      ],
    );

    final hints = hintsForExercise(exercise, const []);

    // Seria robocza dziedziczy po roboczej, nie po rozgrzewce.
    expect(hints['b']!.weightG, (value: 22500, source: HintSource.earlierSet));
    // Plan ma pierwszeństwo przed wcześniejszą serią.
    expect(hints['b']!.reps, (value: 8, source: HintSource.plan));
    expect(hints['c']!.weightG!.value, 22500);
    expect(hints['c']!.reps, (value: 10, source: HintSource.entered));
  });

  test('poprzednie wykonanie ma pierwszeństwo przed wcześniejszą serią', () {
    const exercise = SessionExercise(
      id: 'e',
      exerciseId: 'db',
      position: 0,
      exerciseNameSnapshot: 'Hantle',
      measurementSnapshot: Measurement.weightAndReps,
      loadModeSnapshot: LoadMode.external,
      weightSemanticsSnapshot: WeightSemantics.total,
      isUnilateralSnapshot: false,
      sets: [
        SessionSet(id: 'a', position: 0, weightG: 25000, reps: 8),
        SessionSet(id: 'b', position: 1),
      ],
    );

    final hints = hintsForExercise(exercise, [
      _prev(0, 20000, 10),
      _prev(1, 20000, 9),
    ]);

    expect(hints['b']!.weightG, (value: 20000, source: HintSource.previous));
  });
}
