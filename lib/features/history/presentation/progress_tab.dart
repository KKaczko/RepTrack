import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_providers.dart';
import '../../../core/domain/local_date.dart';
import '../../../core/domain/units.dart';
import '../../../core/l10n/formatters.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/charts.dart';
import '../../../core/widgets/empty_state.dart';
import '../../exercises/data/exercise_providers.dart';
import '../../exercises/domain/exercise.dart';
import '../../progress/domain/metrics.dart';
import '../../settings/data/settings_providers.dart';
import '../../workout/data/workout_providers.dart';
import '../../workout/domain/workout_session.dart';
import '../domain/history_queries.dart';
import 'history_labels.dart';

/// Progres: treningi w tygodniu oraz szacowany 1RM i objętość wybranego
/// ćwiczenia w czasie (spec. 5.5).
class ProgressTab extends ConsumerStatefulWidget {
  const ProgressTab({super.key});

  @override
  ConsumerState<ProgressTab> createState() => _ProgressTabState();
}

class _ProgressTabState extends ConsumerState<ProgressTab> {
  String? _exerciseId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final history = ref.watch(completedSessionsProvider).value;
    if (history == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (history.isEmpty) {
      return EmptyState(
        icon: Icons.show_chart_rounded,
        title: l10n.historyEmptyTitle,
        message: l10n.progressEmpty,
      );
    }
    final locale = Localizations.localeOf(context).toString();
    final now = ref.watch(clockProvider).nowUtc().toLocal();
    final weeks = workoutsPerWeek(
      history,
      LocalDate(now.year, now.month, now.day),
    );
    final catalog = ref.watch(exercisesByIdProvider).value ?? const {};
    final exercises = _exercisesByRecency(history);
    final selected = exercises.contains(_exerciseId)
        ? _exerciseId!
        : exercises.first;
    final name =
        catalog[selected]?.name ??
        exercisePerformances(
          history,
          selected,
        ).first.exercise.exerciseNameSnapshot;

    return ListView(
      key: const PageStorageKey('progress'),
      padding: const EdgeInsets.all(AppSpacing.gutter),
      children: [
        Text(l10n.progressWeekly, style: theme.textTheme.titleMedium),
        const SizedBox(height: AppSpacing.m),
        ValueBarChart(
          values: [for (final w in weeks) w.count.toDouble()],
          integerAxis: true,
          xLabel: (i) => axisDate(weeks[i].weekStart, locale),
          yLabel: (y) => formatDecimal(y, locale, maxDecimals: 0),
          tooltip: (i) =>
              '${axisDate(weeks[i].weekStart, locale)} · '
              '${l10n.workoutsCount(weeks[i].count)}',
          semanticLabel: l10n.chartSemantics(
            l10n.progressWeekly,
            weeks.length,
            l10n.workoutsCount(weeks.last.count),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        OutlinedButton.icon(
          onPressed: () => _pickExercise(exercises, catalog, history),
          icon: const Icon(Icons.fitness_center_rounded),
          label: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
        const SizedBox(height: AppSpacing.l),
        ExerciseCharts(
          performances: [
            for (final p in exercisePerformances(history, selected))
              (date: p.session.localDate, exercise: p.exercise),
          ],
        ),
      ],
    );
  }

  /// Ćwiczenia z historii od ostatnio wykonanego.
  static List<String> _exercisesByRecency(List<WorkoutSession> history) {
    final seen = <String>{};
    return [
      for (final session in history)
        for (final e in session.exercises)
          if (seen.add(e.exerciseId)) e.exerciseId,
    ];
  }

  Future<void> _pickExercise(
    List<String> ids,
    Map<String, Exercise> catalog,
    List<WorkoutSession> history,
  ) async {
    final l10n = AppLocalizations.of(context);
    String nameOf(String id) =>
        catalog[id]?.name ??
        exercisePerformances(history, id).first.exercise.exerciseNameSnapshot;
    final picked = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.gutter,
              ),
              child: Text(
                l10n.progressPickExercise,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final id in ids)
                    ListTile(
                      title: Text(nameOf(id)),
                      onTap: () => Navigator.of(context).pop(id),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    if (picked != null) setState(() => _exerciseId = picked);
  }
}

/// Wykresy jednego ćwiczenia: szacowany 1RM i objętość na trening (zakładka
/// Progres i zakładka „Wykresy” ekranu ćwiczenia).
class ExerciseCharts extends ConsumerWidget {
  const ExerciseCharts({required this.performances, super.key});

  final List<({LocalDate date, SessionExercise exercise})> performances;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toString();
    final unit =
        ref.watch(appSettingsProvider).value?.weightUnit ?? WeightUnit.kg;
    final e1rm = e1rmTrend(performances);
    final volume = volumeTrend(performances);
    final recentVolume = volume.length > 12
        ? volume.sublist(volume.length - 12)
        : volume;
    String kg(double grams) => formatEstimate(grams, unit, locale);

    Widget noData() => Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.m),
      child: Text(
        l10n.progressNoData,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );

    final first = e1rm.firstOrNull?.date;
    double dayOf(LocalDate d) => DateTime.utc(d.year, d.month, d.day)
        .difference(DateTime.utc(first!.year, first.month, first.day))
        .inDays
        .toDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.progressE1rm, style: theme.textTheme.titleMedium),
        const SizedBox(height: AppSpacing.m),
        if (e1rm.length < 2)
          noData()
        else
          TrendLineChart(
            spots: [
              for (final p in e1rm)
                (x: dayOf(p.date), y: gramsToDisplay(p.value.round(), unit)),
            ],
            xLabel: (x) => axisDate(first!.addDays(x.round()), locale),
            yLabel: (y) => formatDecimal(y, locale, maxDecimals: 0),
            tooltip: (i) =>
                '${axisDate(e1rm[i].date, locale)} · ${kg(e1rm[i].value)}',
            semanticLabel: l10n.chartSemantics(
              l10n.progressE1rm,
              e1rm.length,
              kg(e1rm.last.value),
            ),
          ),
        const SizedBox(height: AppSpacing.xl),
        Text(l10n.progressVolume, style: theme.textTheme.titleMedium),
        const SizedBox(height: AppSpacing.m),
        if (recentVolume.isEmpty)
          noData()
        else
          ValueBarChart(
            values: [
              for (final p in recentVolume)
                gramsToDisplay(p.value.round(), unit),
            ],
            xLabel: (i) => axisDate(recentVolume[i].date, locale),
            yLabel: (y) => formatDecimal(y, locale, maxDecimals: 0),
            tooltip: (i) =>
                '${axisDate(recentVolume[i].date, locale)} · '
                '${formatVolume(recentVolume[i].value.round(), unit, locale)}',
            semanticLabel: l10n.chartSemantics(
              l10n.progressVolume,
              recentVolume.length,
              formatVolume(recentVolume.last.value.round(), unit, locale),
            ),
          ),
      ],
    );
  }
}
