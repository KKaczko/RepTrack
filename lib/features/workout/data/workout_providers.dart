import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_providers.dart';
import '../domain/workout_repository.dart';
import 'drift_workout_repository.dart';

final workoutRepositoryProvider = Provider<WorkoutRepository>(
  (ref) => DriftWorkoutRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(clockProvider),
  ),
);
