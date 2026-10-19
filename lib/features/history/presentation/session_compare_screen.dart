import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/domain/units.dart';
import '../../../core/l10n/formatters.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/empty_state.dart';
import '../../exercises/data/exercise_providers.dart';
import '../../settings/data/settings_providers.dart';
import '../../workout/data/workout_providers.dart';
import '../domain/history_queries.dart';
import 'history_labels.dart';

/// Porównanie treningu z poprzednim, ćwiczenie po ćwiczeniu (spec. 5.4).
/// Poprzednie wykonanie to ostatni wcześniejszy trening z tym ćwiczeniem,
/// niezależnie od szablonu (ADR 0006).
class SessionCompareScreen extends ConsumerWidget {
  const SessionCompareScreen({required this.sessionId, super.key});

  final String sessionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final history = ref.watch(completedSessionsProvider);
    final session = history.value?.firstWhereOrNull((s) => s.id == sessionId);
    if (session == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.compareTitle)),
        body: history.isLoading
            ? const Center(child: CircularProgressIndicator())
            : EmptyState(
                icon: Icons.search_off_rounded,
                title: l10n.sessionNotFound,
                message: '',
              ),
      );
    }
    final locale = Localizations.localeOf(context).toString();
    final unit =
        ref.watch(appSettingsProvider).value?.weightUnit ?? WeightUnit.kg;
    final catalog = ref.watch(exercisesByIdProvider).value ?? const {};
    final rows = compareWithPrevious(session, history.value!);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.compareTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.gutter,
          0,
          AppSpacing.gutter,
          AppSpacing.xxl,
        ),
        children: [
          Text(
            '${session.title ?? l10n.workoutTitle} · '
            '${l10n.sessionWhen(session, locale)}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          for (final row in rows)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.l),
              child: _ComparisonCard(
                row: row,
                name: l10n.exerciseName(row.current, catalog),
                unit: unit,
                locale: locale,
              ),
            ),
        ],
      ),
    );
  }
}

class _ComparisonCard extends StatelessWidget {
  const _ComparisonCard({
    required this.row,
    required this.name,
    required this.unit,
    required this.locale,
  });

  final ExerciseComparison row;
  final String name;
  final WeightUnit unit;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final previous = row.previous;
    final label = theme.textTheme.labelMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final values = theme.textTheme.bodyMedium?.copyWith(
      fontFeatures: AppTheme.tabularFigures,
    );

    Widget column(String title, String sets) => Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: label),
          const SizedBox(height: AppSpacing.xs),
          Text(sets.isEmpty ? '—' : sets, style: values),
        ],
      ),
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.l),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(name, style: theme.textTheme.titleMedium),
            const SizedBox(height: AppSpacing.s),
            if (previous == null)
              Text(l10n.compareNoPrevious, style: label)
            else ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  column(
                    l10n.compareCurrent,
                    l10n.exerciseSets(row.current, unit, locale),
                  ),
                  const SizedBox(width: AppSpacing.m),
                  column(
                    l10n.comparePrevious(
                      shortDate(previous.session.localDate, locale),
                    ),
                    l10n.exerciseSets(previous.exercise, unit, locale),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.m),
              if (row.volumeG > 0 || (row.previousVolumeG ?? 0) > 0)
                _DeltaRow(
                  label: l10n.compareVolume,
                  current: row.volumeG.toDouble(),
                  previous: row.previousVolumeG?.toDouble(),
                  format: (g) => formatVolume(g.round(), unit, locale),
                ),
              if (row.bestE1rmG != null || row.previousBestE1rmG != null)
                _DeltaRow(
                  label: l10n.compareE1rm,
                  current: row.bestE1rmG,
                  previous: row.previousBestE1rmG,
                  format: (g) => formatEstimate(g, unit, locale),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Wartość bieżąca, poprzednia i różnica ze strzałką (kolor i znak razem,
/// więc kierunek nie zależy tylko od koloru).
class _DeltaRow extends StatelessWidget {
  const _DeltaRow({
    required this.label,
    required this.current,
    required this.previous,
    required this.format,
  });

  final String label;
  final double? current;
  final double? previous;
  final String Function(double grams) format;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final current = this.current;
    final previous = this.previous;
    final delta = current != null && previous != null
        ? current - previous
        : null;
    final colors = context.appColors;
    final (icon, color) = switch (delta) {
      null || 0 => (Icons.remove_rounded, theme.colorScheme.onSurfaceVariant),
      > 0 => (Icons.arrow_upward_rounded, colors.success),
      _ => (Icons.arrow_downward_rounded, theme.colorScheme.error),
    };
    final style = theme.textTheme.bodyMedium?.copyWith(
      fontFeatures: AppTheme.tabularFigures,
    );
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.s),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          Wrap(
            spacing: AppSpacing.s,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                '${current == null ? '—' : format(current)} · '
                '${previous == null ? '—' : format(previous)}',
                style: style,
              ),
              if (delta != null)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 16, color: color),
                    Text(
                      '${delta > 0
                          ? '+'
                          : delta < 0
                          ? '−'
                          : ''}'
                      '${format(delta.abs())}',
                      style: style?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}
