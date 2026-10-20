import 'package:flutter_test/flutter_test.dart';
import 'package:reptrack/core/domain/local_date.dart';
import 'package:reptrack/core/domain/training.dart';
import 'package:reptrack/features/exercises/domain/exercise.dart';
import 'package:reptrack/features/progress/domain/progress_period.dart';
import 'package:reptrack/features/workout/domain/workout_session.dart';

import '../../../support/workout_fixtures.dart';

const _today = LocalDate(2026, 10, 19);

SessionExercise _exercise(
  String exerciseId,
  List<(int?, int?, int?)> sets, {
  LoadMode loadMode = LoadMode.external,
  Measurement measurement = Measurement.weightAndReps,
  SetType type = SetType.working,
}) => SessionExercise(
  id: 'e-$exerciseId',
  exerciseId: exerciseId,
  position: 0,
  exerciseNameSnapshot: exerciseId,
  measurementSnapshot: measurement,
  loadModeSnapshot: loadMode,
  weightSemanticsSnapshot: WeightSemantics.total,
  isUnilateralSnapshot: false,
  sets: [
    for (final (i, (weight, reps, duration)) in sets.indexed)
      SessionSet(
        id: 's$i',
        position: i,
        setType: type,
        weightG: weight,
        reps: reps,
        durationS: duration,
        completedAt: DateTime.utc(2026, 10, 1),
      ),
  ],
);

void main() {
  group('okresy', () {
    test('zakres i poprzedni okres tej samej długości', () {
      expect(periodRange(ProgressPeriod.weeks4, _today), (
        from: const LocalDate(2026, 9, 22),
        to: _today,
      ));
      expect(previousRange(ProgressPeriod.weeks4, _today), (
        from: const LocalDate(2026, 8, 25),
        to: const LocalDate(2026, 9, 21),
      ));
      expect(periodRange(ProgressPeriod.all, _today).from, isNull);
      expect(previousRange(ProgressPeriod.all, _today), isNull);
    });

    test('liczba tygodni: stała albo od pierwszego treningu', () {
      final history = [
        finishedPush('a', DateTime.utc(2026, 8, 3, 16), [(80000, 8)]),
      ];
      expect(periodWeeks(ProgressPeriod.months3, history, _today), 13);
      // 3 sierpnia (pon.) → 19 października (pon.): 11 tygodni wstecz + bieżący.
      expect(periodWeeks(ProgressPeriod.all, history, _today), 12);
      expect(periodWeeks(ProgressPeriod.all, const [], _today), 4);
    });
  });

  test('podsumowanie okresu: treningi, serie, objętość, czas', () {
    final history = [
      finishedPush('c', DateTime.utc(2026, 10, 12, 16), [
        (85000, 8),
        (85000, 7),
      ]),
      finishedPush('b', DateTime.utc(2026, 10, 5, 16), [(80000, 10)]),
      finishedPush('a', DateTime.utc(2026, 8, 1, 16), [(70000, 10)]),
    ];

    final summary = summarizePeriod(
      history,
      periodRange(ProgressPeriod.weeks4, _today),
    );

    expect(summary.workouts, 2);
    expect(summary.sets, 3);
    expect(summary.volumeG, 85000 * 15 + 80000 * 10);
    expect(summary.duration, const Duration(minutes: 100));
  });

  test('serie na partię: główne 1, pomocnicze 0,5, bez rozgrzewek', () {
    final session = finishedPush('a', DateTime.utc(2026, 10, 12, 16), [
      (80000, 10),
      (80000, 9),
    ]);
    // Katalog z mięśniami: wyciskanie (klatka; triceps, barki) i podciąganie.
    final catalog = {
      'bench': bench.copyWith(
        primaryMuscles: [MuscleGroup.chest],
        secondaryMuscles: [MuscleGroup.triceps, MuscleGroup.shoulders],
      ),
      'pullup': pullUp.copyWith(primaryMuscles: [MuscleGroup.lats]),
    };

    final perMuscle = weeklySetsPerMuscle(
      [session],
      periodRange(ProgressPeriod.weeks4, _today),
      catalog,
      2,
    );

    // 2 serie robocze ławki na 2 tygodnie; podciągania bez zatwierdzeń.
    expect(
      [for (final m in perMuscle) (m.muscle, m.sets)],
      [
        (MuscleGroup.chest, 1.0),
        (MuscleGroup.triceps, 0.5),
        (MuscleGroup.shoulders, 0.5),
      ],
    );
  });

  group('postęp ćwiczenia', () {
    test('miara według pomiaru i trybu obciążenia', () {
      expect(metricFor(_exercise('x', const [])), ExerciseMetric.e1rm);
      expect(
        metricFor(_exercise('x', const [], loadMode: LoadMode.bodyweight)),
        ExerciseMetric.maxReps,
      );
      expect(
        metricFor(
          _exercise('x', const [], measurement: Measurement.durationOnly),
        ),
        ExerciseMetric.maxDuration,
      );
    });

    test('trend, najlepszy wynik, zmiana w % i najlepsza seria', () {
      final performances = [
        (
          date: const LocalDate(2026, 10, 12),
          exercise: _exercise('bench', const [
            (85000, 8, null),
            (90000, 3, null),
          ]),
        ),
        (
          date: const LocalDate(2026, 10, 5),
          exercise: _exercise('bench', const [(80000, 8, null)]),
        ),
        (
          date: const LocalDate(2026, 8, 1),
          exercise: _exercise('bench', const [(100000, 1, null)]),
        ),
      ];

      final progress = exerciseProgress(
        performances,
        periodRange(ProgressPeriod.weeks4, _today),
      );

      expect(progress.metric, ExerciseMetric.e1rm);
      expect(
        [for (final p in progress.trend) p.date],
        [const LocalDate(2026, 10, 5), const LocalDate(2026, 10, 12)],
      );
      // 80 kg × 8 → 85 kg × 8: wzrost szacowanego 1RM o 6,25%.
      expect(progress.changePercent, closeTo(6.25, 0.001));
      expect((progress.bestSet!.weightG, progress.bestSet!.reps), (90000, 3));
      expect(progress.workouts, 2);
      expect(progress.volumeG, 85000 * 8 + 90000 * 3 + 80000 * 8);
    });

    test('masa ciała: najwięcej powtórzeń; jeden dzień bez zmiany %', () {
      final progress = exerciseProgress([
        (
          date: const LocalDate(2026, 10, 12),
          exercise: _exercise('pushup', const [
            (null, 20, null),
            (null, 25, null),
          ], loadMode: LoadMode.bodyweight),
        ),
      ], periodRange(ProgressPeriod.all, _today));

      expect(progress.metric, ExerciseMetric.maxReps);
      expect(progress.best, 25);
      expect(progress.changePercent, isNull);
      expect(progress.bestSet!.reps, 25);
    });

    test('dwa treningi jednego dnia: dwa wykonania, jeden punkt trendu', () {
      final progress = exerciseProgress([
        (
          date: const LocalDate(2026, 10, 12),
          exercise: _exercise('bench', const [(85000, 8, null)]),
        ),
        (
          date: const LocalDate(2026, 10, 12),
          exercise: _exercise('bench', const [(80000, 10, null)]),
        ),
      ], periodRange(ProgressPeriod.weeks4, _today));

      expect(progress.workouts, 2);
      expect(progress.trend, hasLength(1));
      expect(progress.volumeG, 85000 * 8 + 80000 * 10);
    });
  });
}
