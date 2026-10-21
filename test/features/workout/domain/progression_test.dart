import 'package:flutter_test/flutter_test.dart';
import 'package:reptrack/core/domain/training.dart';
import 'package:reptrack/core/domain/units.dart';
import 'package:reptrack/features/exercises/domain/exercise.dart';
import 'package:reptrack/features/workout/domain/progression.dart';
import 'package:reptrack/features/workout/domain/set_hints.dart';
import 'package:reptrack/features/workout/domain/workout_session.dart';

final _done = DateTime.utc(2026, 10, 12, 17);

/// Ćwiczenie z rozgrzewką i trzema seriami roboczymi 8–12.
SessionExercise _exercise({
  LoadMode loadMode = LoadMode.external,
  Measurement measurement = Measurement.weightAndReps,
  TargetKind targetKind = TargetKind.reps,
}) => SessionExercise(
  id: 'e',
  exerciseId: 'bench',
  position: 0,
  exerciseNameSnapshot: 'Wyciskanie',
  measurementSnapshot: measurement,
  loadModeSnapshot: loadMode,
  weightSemanticsSnapshot: WeightSemantics.total,
  isUnilateralSnapshot: false,
  sets: [
    const SessionSet(id: 'w', position: 0, setType: SetType.warmup),
    for (var i = 1; i <= 3; i++)
      SessionSet(
        id: 's$i',
        position: i,
        targetKind: targetKind,
        targetMin: 8,
        targetMax: 12,
      ),
  ],
);

/// Poprzednie wykonanie: rozgrzewka i serie robocze (ciężar, powtórzenia).
List<SessionSet> _previous(
  List<(int, int)> working, {
  EffortScale? scale,
  int? effortTenths,
}) => [
  SessionSet(
    id: 'pw',
    position: 0,
    setType: SetType.warmup,
    weightG: 40000,
    reps: 10,
    completedAt: _done,
  ),
  for (final (i, (weight, reps)) in working.indexed)
    SessionSet(
      id: 'p$i',
      position: i + 1,
      weightG: weight,
      reps: reps,
      effortScale: scale,
      effortTenths: effortTenths,
      completedAt: _done,
    ),
];

ProgressionAdvice? _advice(
  SessionExercise exercise,
  List<SessionSet> previous, {
  double step = 2.5,
  WeightUnit unit = WeightUnit.kg,
}) => progressionFor(exercise, previous, step: step, unit: unit);

void main() {
  test('góra zakresu we wszystkich seriach: +krok i dolna granica', () {
    final advice = _advice(
      _exercise(),
      _previous([(80000, 12), (80000, 12), (80000, 13)]),
    );

    expect(advice, (
      weightG: 82500,
      previousWeightG: 80000,
      previousSets: 3,
      previousReps: 12,
      reason: ProgressionReason.topOfRange,
    ));
  });

  test('choć jedna seria poniżej góry: ciężar zostaje', () {
    expect(
      _advice(_exercise(), _previous([(80000, 12), (80000, 11), (80000, 12)])),
      isNull,
    );
  });

  test('brak wyniku dla jednej serii roboczej: bez progresji', () {
    expect(_advice(_exercise(), _previous([(80000, 12), (80000, 12)])), isNull);
  });

  test('różne ciężary w seriach: bez progresji', () {
    expect(
      _advice(_exercise(), _previous([(80000, 12), (82500, 12), (80000, 12)])),
      isNull,
    );
  });

  test('duży zapas (RIR ≥ 3) w zakresie: +krok', () {
    final advice = _advice(
      _exercise(),
      _previous(
        [(80000, 9), (80000, 9), (80000, 8)],
        scale: EffortScale.rir,
        effortTenths: 30,
      ),
    );

    expect(advice?.weightG, 82500);
    expect(advice?.reason, ProgressionReason.easyEffort);
    expect(advice?.previousReps, 8);
  });

  test('RPE ≤ 7 to zapas, RPE 8 i RIR 2 już nie', () {
    final working = [(80000, 9), (80000, 9), (80000, 9)];
    expect(
      _advice(
        _exercise(),
        _previous(working, scale: EffortScale.rpe, effortTenths: 70),
      )?.reason,
      ProgressionReason.easyEffort,
    );
    expect(
      _advice(
        _exercise(),
        _previous(working, scale: EffortScale.rpe, effortTenths: 80),
      ),
      isNull,
    );
    expect(
      _advice(
        _exercise(),
        _previous(working, scale: EffortScale.rir, effortTenths: 20),
      ),
      isNull,
    );
  });

  test('funty: następny punkt siatki kroku w lb', () {
    final w185lb = displayToGrams(185, WeightUnit.lb);
    final advice = _advice(
      _exercise(),
      _previous([(w185lb, 12), (w185lb, 12), (w185lb, 12)]),
      step: 5,
      unit: WeightUnit.lb,
    );

    expect(advice?.weightG, displayToGrams(190, WeightUnit.lb));
  });

  test('ciężar spoza siatki trafia na najbliższy wyższy punkt', () {
    final advice = _advice(
      _exercise(),
      _previous([(81000, 12), (81000, 12), (81000, 12)]),
    );

    expect(advice?.weightG, 82500);
  });

  test('wspomaganie: mniej wspomagania, a przy zerze bez porady', () {
    expect(
      _advice(
        _exercise(loadMode: LoadMode.assisted),
        _previous([(20000, 12), (20000, 12), (20000, 12)]),
      )?.weightG,
      17500,
    );
    expect(
      _advice(
        _exercise(loadMode: LoadMode.assisted),
        _previous([(0, 12), (0, 12), (0, 12)]),
      ),
      isNull,
    );
  });

  test('masa ciała z dociążeniem: od zera dochodzi pierwszy krok', () {
    expect(
      _advice(
        _exercise(loadMode: LoadMode.weightedBodyweight),
        _previous([(0, 12), (0, 12), (0, 12)]),
      )?.weightG,
      2500,
    );
  });

  test('bez ciężaru albo z celem czasu: bez progresji', () {
    expect(
      _advice(
        _exercise(measurement: Measurement.repsOnly),
        _previous([(0, 12), (0, 12), (0, 12)]),
      ),
      isNull,
    );
    expect(
      _advice(
        _exercise(targetKind: TargetKind.duration),
        _previous([(80000, 12), (80000, 12), (80000, 12)]),
      ),
      isNull,
    );
  });

  test('podpowiedzi: serie robocze z progresji, rozgrzewka jak ostatnio', () {
    final exercise = _exercise();
    final previous = _previous([(80000, 12), (80000, 12), (80000, 12)]);

    final hints = hintsForExercise(
      exercise,
      previous,
      progressionWeightG: 82500,
    );

    expect(hints['w']!.weightG, (value: 40000, source: HintSource.previous));
    for (final id in ['s1', 's2', 's3']) {
      expect(hints[id]!.weightG, (
        value: 82500,
        source: HintSource.progression,
      ));
      expect(hints[id]!.reps, (value: 8, source: HintSource.progression));
    }
  });

  group('deload', () {
    final weak = [(80000, 7), (80000, 6), (80000, 6)];

    test('dwa słabe treningi przy tym samym ciężarze: −10% w dół do kroku', () {
      final advice = progressionFor(
        _exercise(),
        _previous(weak),
        step: 2.5,
        unit: WeightUnit.kg,
        earlierSets: _previous([(80000, 8), (80000, 7), (80000, 7)]),
      );

      expect(advice, (
        weightG: 70000,
        previousWeightG: 80000,
        previousSets: 3,
        previousReps: 6,
        reason: ProgressionReason.deload,
      ));
    });

    test('jeden słaby trening, inny ciężar wcześniej albo brak historii', () {
      ProgressionAdvice? advice(List<(int, int)> earlier) => progressionFor(
        _exercise(),
        _previous(weak),
        step: 2.5,
        unit: WeightUnit.kg,
        earlierSets: earlier.isEmpty ? const [] : _previous(earlier),
      );

      expect(advice([(80000, 9), (80000, 8), (80000, 8)]), isNull);
      expect(advice([(77500, 6), (77500, 6), (77500, 6)]), isNull);
      expect(advice(const []), isNull);
    });

    test('wspomaganie bez deloadu', () {
      expect(
        progressionFor(
          _exercise(loadMode: LoadMode.assisted),
          _previous(weak),
          step: 2.5,
          unit: WeightUnit.kg,
          earlierSets: _previous(weak),
        ),
        isNull,
      );
    });
  });
}
