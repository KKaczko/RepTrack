import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/exercise_providers.dart';
import '../domain/exercise.dart';
import '../domain/exercise_filter.dart';

final exerciseFilterProvider =
    NotifierProvider<ExerciseFilterNotifier, ExerciseFilter>(
      ExerciseFilterNotifier.new,
    );

class ExerciseFilterNotifier extends Notifier<ExerciseFilter> {
  @override
  ExerciseFilter build() => const ExerciseFilter();

  void setQuery(String query) => state = state.copyWith(query: query);

  void update(ExerciseFilter Function(ExerciseFilter filter) change) =>
      state = change(state);

  /// Czyści filtry, zachowując frazę wyszukiwania.
  void clearFilters() => state = ExerciseFilter(query: state.query);
}

final filteredExercisesProvider = Provider<AsyncValue<List<Exercise>>>((ref) {
  final filter = ref.watch(exerciseFilterProvider);
  return ref
      .watch(exerciseCatalogProvider)
      .whenData((all) => applyExerciseFilter(all, filter));
});

final exerciseByIdProvider = Provider.family<AsyncValue<Exercise?>, String>(
  (ref, id) => ref
      .watch(exerciseCatalogProvider)
      .whenData((all) => all.firstWhereOrNull((e) => e.id == id)),
);
