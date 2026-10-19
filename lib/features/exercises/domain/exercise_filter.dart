import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../core/domain/text_normalize.dart';
import 'exercise.dart';

part 'exercise_filter.freezed.dart';

/// Pochodzenie ćwiczenia w filtrze katalogu.
enum ExerciseOrigin { all, builtin, user }

/// Filtr katalogu ćwiczeń. W obrębie jednej grupy (np. mięśnie) wybrane
/// wartości łączy „lub”, a grupy między sobą „i”.
@freezed
abstract class ExerciseFilter with _$ExerciseFilter {
  const factory ExerciseFilter({
    @Default('') String query,

    /// Dopasowanie po mięśniach głównych.
    @Default(<MuscleGroup>{}) Set<MuscleGroup> muscles,
    @Default(<Equipment>{}) Set<Equipment> equipment,
    @Default(<ExerciseCategory>{}) Set<ExerciseCategory> categories,
    @Default(ExerciseOrigin.all) ExerciseOrigin origin,

    /// `true` pokazuje wyłącznie zarchiwizowane, `false` wyłącznie aktywne.
    @Default(false) bool archived,
  }) = _ExerciseFilter;

  const ExerciseFilter._();

  /// Liczba aktywnych filtrów poza frazą wyszukiwania.
  int get activeCount =>
      muscles.length +
      equipment.length +
      categories.length +
      (origin == ExerciseOrigin.all ? 0 : 1) +
      (archived ? 1 : 0);
}

/// Zwraca ćwiczenia pasujące do [filter].
///
/// Bez frazy wynik jest posortowany po nazwie bez polskich znaków. Z frazą
/// kolejność to: nazwa zaczyna się od frazy, nazwa zawiera frazę, pasuje
/// tylko alias; w obrębie grupy alfabetycznie.
List<Exercise> applyExerciseFilter(
  Iterable<Exercise> exercises,
  ExerciseFilter filter,
) {
  final query = normalizeForSearch(filter.query);
  final scored = <(int, String, Exercise)>[];
  for (final exercise in exercises) {
    if (exercise.isArchived != filter.archived) continue;
    if (!_matchesOrigin(exercise, filter.origin)) continue;
    if (filter.muscles.isNotEmpty &&
        !exercise.primaryMuscles.any(filter.muscles.contains)) {
      continue;
    }
    if (filter.equipment.isNotEmpty &&
        !filter.equipment.contains(exercise.equipment)) {
      continue;
    }
    if (filter.categories.isNotEmpty &&
        !filter.categories.contains(exercise.category)) {
      continue;
    }
    final name = normalizeForSearch(exercise.name);
    if (query.isEmpty) {
      scored.add((0, name, exercise));
      continue;
    }
    if (!matchesSearch(exercise.searchText, query)) continue;
    final rank = name.startsWith(query)
        ? 0
        : matchesSearch(name, query)
        ? 1
        : 2;
    scored.add((rank, name, exercise));
  }
  scored.sort((a, b) {
    final byRank = a.$1.compareTo(b.$1);
    return byRank != 0 ? byRank : a.$2.compareTo(b.$2);
  });
  return [for (final (_, _, exercise) in scored) exercise];
}

bool _matchesOrigin(Exercise exercise, ExerciseOrigin origin) =>
    switch (origin) {
      ExerciseOrigin.all => true,
      ExerciseOrigin.builtin => exercise.source == ExerciseSource.builtin,
      ExerciseOrigin.user => exercise.source == ExerciseSource.user,
    };
