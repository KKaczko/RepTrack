import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_providers.dart';
import '../../../core/domain/local_date.dart';
import '../../../core/domain/units.dart';
import '../../../core/l10n/formatters.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/charts.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/stat_tile.dart';
import '../../exercises/data/exercise_providers.dart';
import '../../exercises/domain/exercise.dart';
import '../../exercises/presentation/exercise_labels.dart';
import '../../progress/domain/progress_period.dart';
import '../../settings/data/settings_providers.dart';
import '../../workout/data/workout_providers.dart';
import '../../workout/domain/workout_session.dart';
import '../domain/history_queries.dart';
import 'exercise_progress_section.dart';
import 'history_labels.dart';

/// Progres (spec. 5.5): wybór okresu, podsumowanie z porównaniem do
/// poprzedniego okresu, treningi w tygodniu, serie na partię mięśniową
/// i postęp wybranego ćwiczenia.
class ProgressTab extends ConsumerStatefulWidget {
  const ProgressTab({super.key});

  @override
  ConsumerState<ProgressTab> createState() => _ProgressTabState();
}

class _ProgressTabState extends ConsumerState<ProgressTab> {
  String? _exerciseId;
  ProgressPeriod _period = ProgressPeriod.weeks4;

  /// Najwięcej słupków na wykresie tygodni (cała historia).
  static const _maxWeekBars = 52;

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
    final unit =
        ref.watch(appSettingsProvider).value?.weightUnit ?? WeightUnit.kg;
    final now = ref.watch(clockProvider).nowUtc().toLocal();
    final today = LocalDate(now.year, now.month, now.day);
    final range = periodRange(_period, today);
    final previous = previousRange(_period, today);
    final summary = summarizePeriod(history, range);
    final before = previous == null ? null : summarizePeriod(history, previous);
    final weekCount = periodWeeks(_period, history, today);
    final weeks = workoutsPerWeek(
      history,
      today,
      weeks: weekCount > _maxWeekBars ? _maxWeekBars : weekCount,
    );
    final catalog = ref.watch(exercisesByIdProvider).value ?? const {};
    final muscles = weeklySetsPerMuscle(history, range, catalog, weekCount);
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
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final compared = switch (_period) {
      ProgressPeriod.weeks4 => l10n.progressCompared4w,
      ProgressPeriod.months3 => l10n.progressCompared3m,
      ProgressPeriod.year => l10n.progressComparedYear,
      ProgressPeriod.all => null,
    };

    return ListView(
      key: const PageStorageKey('progress'),
      padding: const EdgeInsets.all(AppSpacing.gutter),
      children: [
        SegmentedButton<ProgressPeriod>(
          showSelectedIcon: false,
          segments: [
            for (final period in ProgressPeriod.values)
              ButtonSegment(
                value: period,
                label: Text(_periodLabel(l10n, period)),
              ),
          ],
          selected: {_period},
          onSelectionChanged: (s) => setState(() => _period = s.single),
        ),
        _Title(l10n.progressSummary),
        StatGrid(
          tiles: [
            StatTile(
              label: l10n.progressWorkouts,
              value: '${summary.workouts}',
              delta: before == null
                  ? null
                  : countDelta(l10n, summary.workouts, before.workouts),
            ),
            StatTile(
              label: l10n.progressSets,
              value: '${summary.sets}',
              delta: before == null
                  ? null
                  : countDelta(l10n, summary.sets, before.sets),
            ),
            StatTile(
              label: l10n.progressVolume,
              value: formatVolume(summary.volumeG, unit, locale),
              delta: before == null
                  ? null
                  : percentDelta(l10n, locale, summary.volumeG, before.volumeG),
            ),
            StatTile(
              label: l10n.progressTime,
              value: l10n.duration(summary.duration),
              delta: before == null
                  ? null
                  : percentDelta(
                      l10n,
                      locale,
                      summary.duration.inMinutes,
                      before.duration.inMinutes,
                    ),
            ),
          ],
        ),
        if (compared != null)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.s),
            child: Text(compared, style: muted),
          ),
        _Title(l10n.progressWeekly),
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
        _Title(l10n.progressMuscles),
        Text(l10n.progressMusclesHint, style: muted),
        const SizedBox(height: AppSpacing.m),
        if (muscles.isEmpty)
          Text(l10n.progressMusclesEmpty, style: muted)
        else
          MuscleBars(rows: muscles),
        _Title(l10n.progressExercise),
        OutlinedButton.icon(
          onPressed: () => _pickExercise(exercises, catalog, history),
          icon: const Icon(Icons.fitness_center_rounded),
          label: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
        const SizedBox(height: AppSpacing.l),
        ExerciseProgressSection(
          range: range,
          performances: [
            for (final p in exercisePerformances(history, selected))
              (date: p.session.localDate, exercise: p.exercise),
          ],
        ),
      ],
    );
  }

  static String _periodLabel(AppLocalizations l10n, ProgressPeriod period) =>
      switch (period) {
        ProgressPeriod.weeks4 => l10n.progressPeriod4w,
        ProgressPeriod.months3 => l10n.progressPeriod3m,
        ProgressPeriod.year => l10n.progressPeriodYear,
        ProgressPeriod.all => l10n.progressPeriodAll,
      };

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
      // Nad shellem: dolna nawigacja nie zasłania listy.
      useRootNavigator: true,
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

class _Title extends StatelessWidget {
  const _Title(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: AppSpacing.xl, bottom: AppSpacing.m),
    child: Text(text, style: Theme.of(context).textTheme.titleMedium),
  );
}

/// Serie na partię mięśniową jako poziome paski: jedna seria danych w kolorze
/// akcentu, nazwy i wartości w kolorach tekstu.
class MuscleBars extends StatelessWidget {
  const MuscleBars({required this.rows, super.key});

  final List<({MuscleGroup muscle, double sets})> rows;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toString();
    final top = rows.first.sets;
    final color = theme.brightness == Brightness.dark
        ? context.appColors.accentFill
        : theme.colorScheme.primary;
    return Column(
      children: [
        for (final row in rows)
          Semantics(
            container: true,
            label: l10n.progressMuscleSemantics(
              l10n.muscle(row.muscle),
              formatDecimal(row.sets, locale, maxDecimals: 1),
            ),
            excludeSemantics: true,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              child: Row(
                children: [
                  Expanded(
                    flex: 5,
                    child: Text(
                      l10n.muscle(row.muscle),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                  Expanded(
                    flex: 6,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: top <= 0 ? 0 : row.sets / top,
                        child: Container(
                          height: 8,
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 48,
                    child: Text(
                      formatDecimal(row.sets, locale, maxDecimals: 1),
                      textAlign: TextAlign.end,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontFeatures: AppTheme.tabularFigures,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
