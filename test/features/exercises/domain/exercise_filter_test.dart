import 'package:flutter_test/flutter_test.dart';
import 'package:reptrack/features/exercises/domain/exercise.dart';
import 'package:reptrack/features/exercises/domain/exercise_filter.dart';

final _catalog = [
  const Exercise(
    id: 'bench',
    name: 'Wyciskanie sztangi na ławce płaskiej',
    aliases: ['Bench press'],
    primaryMuscles: [MuscleGroup.chest],
    secondaryMuscles: [MuscleGroup.triceps],
    equipment: Equipment.barbell,
    source: ExerciseSource.builtin,
  ),
  const Exercise(
    id: 'lawka',
    name: 'Ławka rzymska',
    aliases: ['Back extension'],
    primaryMuscles: [MuscleGroup.lowerBack],
    equipment: Equipment.other,
    source: ExerciseSource.builtin,
  ),
  const Exercise(
    id: 'dips',
    name: 'Pompki na poręczach',
    aliases: ['Dipy', 'Triceps dips'],
    primaryMuscles: [MuscleGroup.triceps],
    secondaryMuscles: [MuscleGroup.chest],
    equipment: Equipment.other,
    source: ExerciseSource.builtin,
  ),
  const Exercise(
    id: 'moje',
    name: 'Moje wyciskanie na maszynie',
    primaryMuscles: [MuscleGroup.chest],
    equipment: Equipment.machine,
  ),
  Exercise(
    id: 'stare',
    name: 'Stare ćwiczenie',
    primaryMuscles: const [MuscleGroup.chest],
    archivedAt: DateTime.utc(2026),
  ),
  const Exercise(
    id: 'bieg',
    name: 'Bieg na bieżni',
    primaryMuscles: [MuscleGroup.quadriceps],
    equipment: Equipment.machine,
    category: ExerciseCategory.cardio,
    source: ExerciseSource.builtin,
  ),
];

List<String> _ids(ExerciseFilter filter) => [
  for (final e in applyExerciseFilter(_catalog, filter)) e.id,
];

void main() {
  test('bez filtrów: aktywne ćwiczenia alfabetycznie bez polskich znaków', () {
    expect(_ids(const ExerciseFilter()), [
      'bieg',
      'lawka',
      'moje',
      'dips',
      'bench',
    ]);
  });

  test(
    '„lawka” znajduje „Ławka”, a „lawce” odmienioną formę w środku nazwy',
    () {
      expect(_ids(const ExerciseFilter(query: 'lawka')), ['lawka']);
      expect(_ids(const ExerciseFilter(query: 'lawce plaskiej')), ['bench']);
    },
  );

  test('wyszukiwanie po aliasie angielskim', () {
    expect(_ids(const ExerciseFilter(query: 'bench press')), ['bench']);
    expect(_ids(const ExerciseFilter(query: 'DIPY')), ['dips']);
  });

  test('ranking: początek nazwy, potem zawieranie, potem alias', () {
    final withAlias = [
      ..._catalog,
      const Exercise(id: 'alias', name: 'Zzz', aliases: ['wyciskanie x']),
    ];

    final result = applyExerciseFilter(
      withAlias,
      const ExerciseFilter(query: 'wyciskanie'),
    );

    expect([for (final e in result) e.id], ['bench', 'moje', 'alias']);
  });

  test('filtr mięśni dopasowuje mięśnie główne', () {
    expect(_ids(const ExerciseFilter(muscles: {MuscleGroup.chest})), [
      'moje',
      'bench',
    ]);
    expect(
      _ids(
        const ExerciseFilter(muscles: {MuscleGroup.chest, MuscleGroup.triceps}),
      ),
      ['moje', 'dips', 'bench'],
    );
  });

  test('grupy filtrów łączą się przez „i”', () {
    expect(
      _ids(
        const ExerciseFilter(
          muscles: {MuscleGroup.chest},
          equipment: {Equipment.machine},
        ),
      ),
      ['moje'],
    );
  });

  test('kategoria i pochodzenie', () {
    expect(_ids(const ExerciseFilter(categories: {ExerciseCategory.cardio})), [
      'bieg',
    ]);
    expect(_ids(const ExerciseFilter(origin: ExerciseOrigin.user)), ['moje']);
    expect(
      _ids(const ExerciseFilter(origin: ExerciseOrigin.builtin)),
      isNot(contains('moje')),
    );
  });

  test('archiwum pokazuje wyłącznie zarchiwizowane', () {
    expect(_ids(const ExerciseFilter(archived: true)), ['stare']);
  });

  test('licznik aktywnych filtrów pomija frazę', () {
    expect(const ExerciseFilter(query: 'x').activeCount, 0);
    expect(
      const ExerciseFilter(
        muscles: {MuscleGroup.chest, MuscleGroup.lats},
        origin: ExerciseOrigin.user,
        archived: true,
      ).activeCount,
      4,
    );
  });
}
