import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_providers.dart';
import '../domain/template_repository.dart';
import 'drift_template_repository.dart';

final templateRepositoryProvider = Provider<TemplateRepository>(
  (ref) => DriftTemplateRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(clockProvider),
  ),
);
