import '../../../core/domain/training.dart';
import '../../../core/domain/units.dart';
import '../../../core/l10n/formatters.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../domain/set_plan.dart';
import '../domain/template.dart';

/// Przerwy do wyboru w szablonie (s); null = domyślna z ustawień.
const restOptions = <int?>[null, ...restChoicesSeconds];

extension TemplateLabels on AppLocalizations {
  String setType(SetType type) => switch (type) {
    SetType.warmup => setTypeWarmup,
    SetType.working => setTypeWorking,
    SetType.drop => setTypeDrop,
    SetType.amrap => setTypeAmrap,
  };

  String targetKind(TargetKind kind) => switch (kind) {
    TargetKind.reps => targetKindReps,
    TargetKind.duration => targetKindDuration,
  };

  String rest(int? seconds) =>
      seconds == null ? restDefault : formatClock(seconds);

  /// Podsumowanie ćwiczenia w szablonie, np. „3 × 8–12 · 80 kg · przerwa 2:00”
  /// albo „4 serie: 12–15 / 10–12 / 8–10 / 6–8”.
  String templateExerciseSummary(
    TemplateExercise exercise,
    WeightUnit unit,
    String locale,
  ) {
    final sets = resolveEffectiveSets(exercise);
    if (sets.isEmpty) return setCount(0);
    final targets = [
      for (final s in sets)
        formatTarget(s.targetKind, s.targetMin, s.targetMax),
    ];
    final parts = <String>[];
    if (targets.toSet().length == 1) {
      parts.add(
        targets.first.isEmpty
            ? setCount(sets.length)
            : '${sets.length} × ${targets.first}',
      );
    } else {
      parts.add(
        '${setCount(sets.length)}: '
        '${targets.map((t) => t.isEmpty ? '—' : t).join(' / ')}',
      );
    }
    final weights = {for (final s in sets) s.targetWeightG};
    if (weights.length == 1 && weights.first != null) {
      parts.add(formatWeight(weights.first!, unit, locale));
    }
    if (exercise.restSeconds != null) {
      parts.add(templateRestSummary(formatClock(exercise.restSeconds!)));
    }
    return parts.join(' · ');
  }

  /// Krótki opis serii, np. „8–12 · 80 kg · Robocza”.
  String effectiveSetSummary(
    EffectiveSet set,
    WeightUnit unit,
    String locale,
  ) => [
    formatTarget(set.targetKind, set.targetMin, set.targetMax),
    if (set.targetWeightG != null)
      formatWeight(set.targetWeightG!, unit, locale),
    setType(set.setType),
  ].where((p) => p.isNotEmpty).join(' · ');
}
