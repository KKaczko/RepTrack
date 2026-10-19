import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_providers.dart';
import '../domain/template.dart';
import '../domain/template_repository.dart';
import 'drift_template_repository.dart';

/// Publiczne providery funkcji „szablony” (docs/architecture.md).
final templateRepositoryProvider = Provider<TemplateRepository>(
  (ref) => DriftTemplateRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(clockProvider),
  ),
);

/// Wszystkie szablony, także zarchiwizowane, posortowane po nazwie.
final templatesProvider = StreamProvider<List<Template>>(
  (ref) =>
      ref.watch(templateRepositoryProvider).watchAll(includeArchived: true),
);
