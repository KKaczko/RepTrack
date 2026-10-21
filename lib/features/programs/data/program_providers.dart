import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_providers.dart';
import '../../../core/domain/local_date.dart';
import '../../exercises/data/exercise_providers.dart';
import '../../exercises/domain/exercise.dart';
import '../../plan/data/plan_providers.dart';
import '../../templates/data/template_providers.dart';
import '../../templates/domain/template.dart';
import '../domain/program.dart';
import '../domain/program_install.dart';

/// Publiczne providery funkcji „gotowe programy” (ADR 0019).

/// Biblioteka programów z zasobów aplikacji.
final programLibraryProvider = FutureProvider<List<Program>>(
  (ref) async => parsePrograms(await rootBundle.loadString(programsAssetPath)),
);

/// Ćwiczenia wbudowane po kluczu seeda, potrzebne programom.
final programExercisesProvider = FutureProvider<Map<String, Exercise>>((
  ref,
) async {
  final ids = await ref.watch(seedExerciseIdsProvider.future);
  final exercises = await ref
      .read(exerciseRepositoryProvider)
      .findAll(includeArchived: true);
  final byId = {for (final e in exercises) e.id: e};
  return {for (final MapEntry(:key, :value) in ids.entries) key: ?byId[value]};
});

final programInstallerProvider = Provider<ProgramInstaller>(
  ProgramInstaller.new,
);

/// Dodaje program: szablony i plan tygodnia od dziś w jednej transakcji,
/// więc przy błędzie nic nie zostaje zapisane.
final class ProgramInstaller {
  ProgramInstaller(this._ref);

  final Ref _ref;

  /// Zwraca dodane szablony (w kolejności treningów programu).
  Future<List<Template>> install(
    Program program, {
    required String languageCode,
  }) async {
    final exercises = await _ref.read(programExercisesProvider.future);
    final problems = validateProgram(program, exercises);
    if (problems.isNotEmpty) throw StateError(problems.join('; '));
    final now = _ref.read(clockProvider).nowUtc().toLocal();
    final plans = _ref.read(planRepositoryProvider);
    final templates = _ref.read(templateRepositoryProvider);
    return _ref.read(appDatabaseProvider).transaction(() async {
      final result = installProgram(
        program,
        exercisesByKey: exercises,
        languageCode: languageCode,
        plans: (await plans.load()).weekly,
        today: LocalDate(now.year, now.month, now.day),
        ids: _ref.read(idGeneratorProvider),
      );
      for (final template in result.templates) {
        await templates.save(template);
      }
      await plans.saveWeekly(
        save: result.plan.save,
        delete: result.plan.delete,
      );
      return result.templates;
    });
  }
}
