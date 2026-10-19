import 'package:flutter_test/flutter_test.dart';
import 'package:reptrack/core/domain/training.dart';
import 'package:reptrack/features/templates/domain/set_plan.dart';
import 'package:reptrack/features/templates/domain/template.dart';

import '../../../support/fakes.dart';

TemplateExercise _bench({int sets = 3}) => TemplateExercise(
  id: 'te-1',
  exerciseId: 'ex-bench',
  position: 0,
  targetMin: 8,
  targetMax: 12,
  targetWeightG: 80000,
  restSeconds: 120,
  sets: [for (var i = 0; i < sets; i++) TemplateSet(id: 'ts-$i', position: i)],
);

void main() {
  group('resolveEffectiveSets', () {
    test('3 × 8–12: wszystkie serie dziedziczą wspólny cel', () {
      final sets = resolveEffectiveSets(_bench());

      expect(sets, hasLength(3));
      for (final set in sets) {
        expect(set.setType, SetType.working);
        expect(set.targetKind, TargetKind.reps);
        expect((set.targetMin, set.targetMax), (8, 12));
        expect(set.targetWeightG, 80000);
        expect(set.restSeconds, 120);
        expect(set.overridesTarget, isFalse);
      }
    });

    test('nadpisanie pojedynczej serii nie zmienia pozostałych', () {
      final exercise = overrideSet(
        _bench(),
        1,
        target: (min: 5, max: 5),
        targetWeightG: 90000,
        setType: SetType.amrap,
      );

      final sets = resolveEffectiveSets(exercise);

      expect((sets[0].targetMin, sets[0].targetMax), (8, 12));
      expect((sets[1].targetMin, sets[1].targetMax), (5, 5));
      expect(sets[1].targetWeightG, 90000);
      expect(sets[1].setType, SetType.amrap);
      expect(sets[1].restSeconds, 120, reason: 'przerwa nadal dziedziczona');
      expect(sets[1].overridesTarget, isTrue);
      expect(sets[1].overridesWeight, isTrue);
      expect(sets[1].overridesRest, isFalse);
      expect((sets[2].targetMin, sets[2].targetMax), (8, 12));
    });

    test('piramida 12–15 / 10–12 / 8–10 / 6–8', () {
      var exercise = _bench(sets: 4);
      const ranges = [(12, 15), (10, 12), (8, 10), (6, 8)];
      for (final (i, (min, max)) in ranges.indexed) {
        exercise = overrideSet(exercise, i, target: (min: min, max: max));
      }

      final sets = resolveEffectiveSets(exercise);

      expect([for (final s in sets) (s.targetMin, s.targetMax)], ranges);
    });

    test('zmiana wspólnego celu propaguje się tylko do serii bez nadpisań', () {
      final exercise = overrideSet(
        _bench(),
        0,
        target: (min: 15, max: 20),
      ).copyWith(targetMin: 6, targetMax: 8);

      final sets = resolveEffectiveSets(exercise);

      expect((sets[0].targetMin, sets[0].targetMax), (15, 20));
      expect((sets[1].targetMin, sets[1].targetMax), (6, 8));
      expect((sets[2].targetMin, sets[2].targetMax), (6, 8));
    });

    test('serie są zwracane w kolejności position', () {
      final exercise = _bench().copyWith(
        sets: const [
          TemplateSet(id: 'b', position: 1, targetMin: 5, targetMax: 5),
          TemplateSet(id: 'a', position: 0),
        ],
      );

      final sets = resolveEffectiveSets(exercise);

      expect([for (final s in sets) s.templateSetId], ['a', 'b']);
      expect([for (final s in sets) s.index], [0, 1]);
    });

    test('cel czasowy dziedziczy rodzaj celu z ćwiczenia', () {
      const plank = TemplateExercise(
        id: 'te-plank',
        exerciseId: 'ex-plank',
        position: 0,
        targetKind: TargetKind.duration,
        targetMin: 30,
        targetMax: 60,
        sets: [TemplateSet(id: 's0', position: 0)],
      );

      final sets = resolveEffectiveSets(plank);

      expect(sets.single.targetKind, TargetKind.duration);
      expect((sets.single.targetMin, sets.single.targetMax), (30, 60));
    });
  });

  group('restoreInheritance', () {
    test('przywraca dziedziczenie wszystkich pól', () {
      final overridden = overrideSet(
        _bench(),
        2,
        target: (min: 3, max: 5),
        targetWeightG: 100000,
        restSeconds: 300,
        setType: SetType.drop,
      );

      final restored = restoreInheritance(overridden, 2);

      expect(restored.sets[2].hasOverrides, isFalse);
      expect(resolveEffectiveSets(restored), resolveEffectiveSets(_bench()));
    });

    test('przywraca tylko wskazane pole', () {
      final overridden = overrideSet(
        _bench(),
        0,
        target: (min: 3, max: 5),
        targetWeightG: 100000,
      );

      final restored = restoreInheritance(
        overridden,
        0,
        fields: {SetField.weight},
      );
      final set = resolveEffectiveSets(restored).first;

      expect(set.targetWeightG, 80000);
      expect((set.targetMin, set.targetMax), (3, 5));
    });
  });

  group('withSetCount', () {
    test('dodane serie dziedziczą wszystko', () {
      final ids = SequentialIds();

      final exercise = withSetCount(_bench(), 5, ids);

      expect(exercise.setCount, 5);
      expect(exercise.sets.skip(3).every((s) => !s.hasOverrides), isTrue);
      expect([for (final s in exercise.sets) s.position], [0, 1, 2, 3, 4]);
      final sets = resolveEffectiveSets(exercise);
      expect(sets.every((s) => s.targetMin == 8 && s.targetMax == 12), isTrue);
    });

    test('zmniejszenie usuwa ostatnie serie i zachowuje nadpisania', () {
      final overridden = overrideSet(_bench(), 0, target: (min: 5, max: 5));

      final exercise = withSetCount(overridden, 2, SequentialIds());

      expect([for (final s in exercise.sets) s.id], ['ts-0', 'ts-1']);
      expect(resolveEffectiveSets(exercise).first.targetMax, 5);
    });

    test('odrzuca liczbę serii mniejszą niż 1', () {
      expect(
        () => withSetCount(_bench(), 0, SequentialIds()),
        throwsArgumentError,
      );
    });
  });

  group('validateTarget', () {
    test('odrzuca min > max i wartości ujemne', () {
      expect(
        () => overrideSet(_bench(), 0, target: (min: 12, max: 8)),
        throwsA(isA<InvalidTargetException>()),
      );
      expect(
        () => validateTarget(-1, 5),
        throwsA(isA<InvalidTargetException>()),
      );
    });

    test('akceptuje pusty cel i pojedynczą liczbę', () {
      validateTarget(null, null);
      validateTarget(10, 10);
      validateTarget(null, 12);
    });
  });
}
