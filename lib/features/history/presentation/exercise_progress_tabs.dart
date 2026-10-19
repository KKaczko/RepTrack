import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/domain/units.dart';
import '../../../core/l10n/formatters.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/empty_state.dart';
import '../../progress/domain/metrics.dart';
import '../../settings/data/settings_providers.dart';
import '../../workout/data/workout_providers.dart';
import '../domain/history_queries.dart';
import 'history_labels.dart';
import 'progress_tab.dart';

/// Zakładki historii, rekordów i wykresów na ekranie ćwiczenia. Router
/// przekazuje je do ekranu ćwiczenia (granice funkcji, docs/architecture.md).
List<
  ({
    String Function(AppLocalizations l10n) label,
    Widget Function(String exerciseId) builder,
  })
>
exerciseProgressTabs() => [
  (
    label: (l10n) => l10n.exerciseTabHistory,
    builder: (id) => ExerciseHistoryTab(exerciseId: id),
  ),
  (
    label: (l10n) => l10n.exerciseTabRecords,
    builder: (id) => ExerciseRecordsTab(exerciseId: id),
  ),
  (
    label: (l10n) => l10n.exerciseTabCharts,
    builder: (id) => ExerciseChartsTab(exerciseId: id),
  ),
];

/// Wykonania ćwiczenia z historii, od najnowszego; null w trakcie ładowania.
List<ExercisePerformance>? _performances(WidgetRef ref, String exerciseId) {
  final history = ref.watch(completedSessionsProvider).value;
  return history == null ? null : exercisePerformances(history, exerciseId);
}

class ExerciseHistoryTab extends ConsumerWidget {
  const ExerciseHistoryTab({required this.exerciseId, super.key});

  final String exerciseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final performances = _performances(ref, exerciseId);
    if (performances == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (performances.isEmpty) {
      return EmptyState(
        icon: Icons.history_rounded,
        title: l10n.exerciseTabHistory,
        message: l10n.exerciseHistoryEmpty,
      );
    }
    final locale = Localizations.localeOf(context).toString();
    final unit =
        ref.watch(appSettingsProvider).value?.weightUnit ?? WeightUnit.kg;
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      itemCount: performances.length,
      itemBuilder: (context, index) {
        final p = performances[index];
        final sets = l10n.exerciseSets(p.exercise, unit, locale);
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.gutter,
          ),
          title: Text(
            '${shortDate(p.session.localDate, locale)} · '
            '${p.session.title ?? l10n.workoutTitle}',
          ),
          subtitle: Text(
            sets.isEmpty ? '—' : sets,
            style: const TextStyle(fontFeatures: AppTheme.tabularFigures),
          ),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => context.push(AppRoutes.sessionDetail(p.session.id)),
        );
      },
    );
  }
}

class ExerciseRecordsTab extends ConsumerWidget {
  const ExerciseRecordsTab({required this.exerciseId, super.key});

  final String exerciseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final performances = _performances(ref, exerciseId);
    if (performances == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final records = datedRecords([
      for (final p in performances)
        (date: p.session.localDate, exercise: p.exercise),
    ]);
    if (records.isEmpty) {
      return EmptyState(
        icon: Icons.emoji_events_outlined,
        title: l10n.exerciseTabRecords,
        message: l10n.recordsEmpty,
      );
    }
    final locale = Localizations.localeOf(context).toString();
    final unit =
        ref.watch(appSettingsProvider).value?.weightUnit ?? WeightUnit.kg;
    final forReps = distinctRepRecords(records.bestWeightForReps);

    Widget row(String label, String value, String date) => ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
      title: Text(label),
      subtitle: Text(date),
      trailing: Text(
        value,
        style: theme.textTheme.titleMedium?.copyWith(
          fontFeatures: AppTheme.tabularFigures,
        ),
      ),
    );

    return ListView(
      key: const PageStorageKey('exercise-records'),
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      children: [
        if (records.bestE1rmG case final e1rm?)
          row(
            l10n.recordsE1rm,
            formatEstimate(e1rm.value, unit, locale),
            shortDate(e1rm.date, locale),
          ),
        if (records.maxReps case final reps?)
          row(
            l10n.recordsMaxReps,
            '${reps.value} ${l10n.workoutUnitReps}',
            shortDate(reps.date, locale),
          ),
        if (forReps.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.gutter,
              AppSpacing.l,
              AppSpacing.gutter,
              AppSpacing.xs,
            ),
            child: Text(
              l10n.recordsWeightForReps,
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
          ),
        for (final (:reps, :best) in forReps)
          row(
            l10n.recordsRepsAtLeast(reps),
            formatWeight(best.value, unit, locale),
            shortDate(best.date, locale),
          ),
      ],
    );
  }
}

class ExerciseChartsTab extends ConsumerWidget {
  const ExerciseChartsTab({required this.exerciseId, super.key});

  final String exerciseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final performances = _performances(ref, exerciseId);
    if (performances == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (performances.isEmpty) {
      return EmptyState(
        icon: Icons.show_chart_rounded,
        title: l10n.exerciseTabCharts,
        message: l10n.exerciseHistoryEmpty,
      );
    }
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.gutter),
      children: [
        ExerciseCharts(
          performances: [
            for (final p in performances)
              (date: p.session.localDate, exercise: p.exercise),
          ],
        ),
      ],
    );
  }
}
