import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_providers.dart';
import '../domain/plan.dart';
import '../domain/plan_repository.dart';
import 'drift_plan_repository.dart';

/// Publiczne providery funkcji „plan” (docs/architecture.md).
final planRepositoryProvider = Provider<PlanRepository>(
  (ref) => DriftPlanRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(clockProvider),
  ),
);

/// Cały plan: wersje planu tygodniowego i wpisy na daty.
final planProvider = StreamProvider<PlanState>(
  (ref) => ref.watch(planRepositoryProvider).watch(),
);
