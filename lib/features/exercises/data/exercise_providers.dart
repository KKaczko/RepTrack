import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_providers.dart';
import '../domain/exercise.dart';
import '../domain/exercise_repository.dart';
import '../domain/substitute_repository.dart';
import '../domain/substitutes.dart';
import 'drift_exercise_repository.dart';
import 'drift_substitute_repository.dart';

/// Publiczne providery funkcji „ćwiczenia”; inne funkcje mogą z nich
/// korzystać (docs/architecture.md).
final exerciseRepositoryProvider = Provider<ExerciseRepository>(
  (ref) => DriftExerciseRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(clockProvider),
  ),
);

/// Cały katalog, także zarchiwizowany; filtrowanie odbywa się w pamięci.
final exerciseCatalogProvider = StreamProvider<List<Exercise>>(
  (ref) =>
      ref.watch(exerciseRepositoryProvider).watchAll(includeArchived: true),
);

/// Katalog jako mapa id → ćwiczenie, do wyświetlania nazw w szablonach
/// i treningu.
final exercisesByIdProvider = Provider<AsyncValue<Map<String, Exercise>>>(
  (ref) => ref
      .watch(exerciseCatalogProvider)
      .whenData((all) => {for (final e in all) e.id: e}),
);

/// Przypięte zamienniki ćwiczeń (ADR 0016).
final substituteRepositoryProvider = Provider<SubstituteRepository>(
  (ref) => DriftSubstituteRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(clockProvider),
    ref.watch(idGeneratorProvider),
  ),
);

/// Wszystkie przypięte pary zamienników.
final substitutePinsProvider = StreamProvider<List<SubstitutePin>>(
  (ref) => ref.watch(substituteRepositoryProvider).watch(),
);
