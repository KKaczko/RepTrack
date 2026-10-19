import 'package:flutter_test/flutter_test.dart';
import 'package:reptrack/core/domain/training.dart';
import 'package:reptrack/features/exercises/domain/exercise.dart';
import 'package:reptrack/features/templates/domain/set_plan.dart';
import 'package:reptrack/features/templates/domain/template.dart';
import 'package:reptrack/features/templates/domain/template_editing.dart';

import '../../../support/fakes.dart';

const _bench = Exercise(id: 'bench', name: 'Wyciskanie');
const _plank = Exercise(
  id: 'plank',
  name: 'Deska',
  measurement: Measurement.durationOnly,
);
const _treadmill = Exercise(
  id: 'run',
  name: 'Bieg',
  category: ExerciseCategory.cardio,
  measurement: Measurement(duration: true, distance: true),
);
const _farmer = Exercise(
  id: 'farmer',
  name: 'Spacer farmera',
  measurement: Measurement(weight: true, distance: true),
);

void main() {
  group('newTemplateExercise', () {
    test('powtórzenia: 3 × 8–12', () {
      final e = newTemplateExercise(_bench, position: 0, ids: SequentialIds());

      expect(e.targetKind, TargetKind.reps);
      expect((e.targetMin, e.targetMax), (8, 12));
      expect(e.setCount, 3);
      expect(e.sets.every((s) => !s.hasOverrides), isTrue);
    });

    test('tylko czas: 3 × 30–60 s', () {
      final e = newTemplateExercise(_plank, position: 0, ids: SequentialIds());

      expect(e.targetKind, TargetKind.duration);
      expect((e.targetMin, e.targetMax), (30, 60));
      expect(e.setCount, 3);
    });

    test('kardio: jedna seria bez celu', () {
      final e = newTemplateExercise(
        _treadmill,
        position: 0,
        ids: SequentialIds(),
      );

      expect(e.targetKind, TargetKind.duration);
      expect((e.targetMin, e.targetMax), (null, null));
      expect(e.setCount, 1);
    });

    test('ciężar i dystans: 3 serie bez celu', () {
      final e = newTemplateExercise(_farmer, position: 0, ids: SequentialIds());

      expect((e.targetMin, e.targetMax), (null, null));
      expect(e.setCount, 3);
    });
  });

  group('edycja listy ćwiczeń', () {
    Template build() => addExercises(const Template(id: 't', name: 'Push'), [
      _bench,
      _plank,
      _farmer,
    ], SequentialIds());

    test('dodawanie zachowuje kolejność i numerację', () {
      final t = build();

      expect(
        [for (final e in t.exercises) e.exerciseId],
        ['bench', 'plank', 'farmer'],
      );
      expect([for (final e in t.exercises) e.position], [0, 1, 2]);
    });

    test('dodanie do istniejącego szablonu dopisuje na końcu', () {
      final t = addExercises(build(), [_treadmill], SequentialIds('x'));

      expect(t.exercises.last.exerciseId, 'run');
      expect(t.exercises.last.position, 3);
    });

    test('przeniesienie w dół i w górę (indeks docelowy po przeniesieniu)', () {
      final down = moveExercise(build(), 0, 2);
      expect(
        [for (final e in down.exercises) e.exerciseId],
        ['plank', 'farmer', 'bench'],
      );

      final up = moveExercise(build(), 2, 0);
      expect(
        [for (final e in up.exercises) e.exerciseId],
        ['farmer', 'bench', 'plank'],
      );
      expect([for (final e in up.exercises) e.position], [0, 1, 2]);
    });

    test('usunięcie przenumerowuje pozostałe', () {
      final t = build();

      final removed = removeExercise(t, t.exercises[1].id);

      expect(
        [for (final e in removed.exercises) e.exerciseId],
        ['bench', 'farmer'],
      );
      expect([for (final e in removed.exercises) e.position], [0, 1]);
    });

    test('zastąpienie aktualizuje jedno ćwiczenie', () {
      final t = build();
      final updated = withSetCount(t.exercises.first, 5, SequentialIds('n'));

      final result = replaceExercise(t, updated);

      expect(result.exercises.first.setCount, 5);
      expect(result.exercises[1], t.exercises[1]);
    });
  });

  group('duplicateTemplate', () {
    test('nowe identyfikatory wszędzie, ta sama treść', () {
      final original = overrideSetIn(
        addExercises(
          const Template(id: 't', name: 'Push', description: 'Opis'),
          [_bench, _plank],
          SequentialIds('a'),
        ),
      );

      final copy = duplicateTemplate(
        original,
        SequentialIds('b'),
        name: 'Push (kopia)',
      );

      expect(copy.id, isNot(original.id));
      expect(copy.name, 'Push (kopia)');
      expect(copy.description, 'Opis');
      expect(copy.archivedAt, isNull);
      final originalIds = {
        for (final e in original.exercises) ...[
          e.id,
          for (final s in e.sets) s.id,
        ],
      };
      final copyIds = {
        for (final e in copy.exercises) ...[e.id, for (final s in e.sets) s.id],
      };
      expect(originalIds.intersection(copyIds), isEmpty);
      List<EffectiveSet> plan(TemplateExercise e) => [
        for (final s in resolveEffectiveSets(e)) s.copyWith(templateSetId: ''),
      ];
      for (final (i, e) in copy.exercises.indexed) {
        expect(plan(e), plan(original.exercises[i]));
      }
    });

    test('grupy superserii dostają nowe, spójne identyfikatory', () {
      final t = addExercises(const Template(id: 't', name: 'A'), [
        _bench,
        _plank,
        _farmer,
      ], SequentialIds());
      final grouped = t.copyWith(
        exercises: [
          t.exercises[0].copyWith(groupId: 'g1'),
          t.exercises[1].copyWith(groupId: 'g1'),
          t.exercises[2],
        ],
      );

      final copy = duplicateTemplate(grouped, SequentialIds('c'), name: 'B');

      expect(copy.exercises[0].groupId, isNotNull);
      expect(copy.exercises[0].groupId, isNot('g1'));
      expect(copy.exercises[0].groupId, copy.exercises[1].groupId);
      expect(copy.exercises[2].groupId, isNull);
    });
  });

  group('validateTemplate', () {
    test('pusta nazwa i zły cel', () {
      final t = addExercises(const Template(id: 't', name: '  '), [
        _bench,
      ], SequentialIds());
      final broken = t.copyWith(
        exercises: [t.exercises.first.copyWith(targetMin: 12, targetMax: 8)],
      );

      expect(validateTemplate(broken), [
        TemplateProblem.emptyName,
        TemplateProblem.invalidTarget,
      ]);
    });

    test('ćwiczenie bez serii', () {
      final t = addExercises(const Template(id: 't', name: 'A'), [
        _bench,
      ], SequentialIds());
      final noSets = t.copyWith(
        exercises: [t.exercises.first.copyWith(sets: const [])],
      );

      expect(validateTemplate(noSets), [TemplateProblem.noSets]);
    });

    test('poprawny szablon i licznik serii', () {
      final t = addExercises(const Template(id: 't', name: 'Push'), [
        _bench,
        _treadmill,
      ], SequentialIds());

      expect(validateTemplate(t), isEmpty);
      expect(totalSets(t), 4);
    });
  });
}

Template overrideSetIn(Template t) => replaceExercise(
  t,
  overrideSet(t.exercises.first, 1, target: (min: 5, max: 5)),
);
