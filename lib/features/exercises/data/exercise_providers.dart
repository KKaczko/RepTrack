import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_providers.dart';
import '../domain/exercise_repository.dart';
import 'drift_exercise_repository.dart';

final exerciseRepositoryProvider = Provider<ExerciseRepository>(
  (ref) => DriftExerciseRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(clockProvider),
  ),
);
