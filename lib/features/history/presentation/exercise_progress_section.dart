import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/domain/glossary.dart';
import '../../../core/domain/local_date.dart';
import '../../../core/domain/units.dart';
import '../../../core/l10n/formatters.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/charts.dart';
import '../../../core/widgets/stat_tile.dart';
import '../../../core/widgets/term_info.dart';
import '../../progress/domain/metrics.dart';
import '../../progress/domain/progress_period.dart';
import '../../settings/data/settings_providers.dart';
import '../../workout/domain/workout_session.dart';
import 'history_labels.dart';

/// Zmiana procentowa jako [StatDelta], np. „+8%”; null bez punktu
/// odniesienia (poprzednia wartość 0 albo brak).
StatDelta? percentDelta(
  AppLocalizations l10n,
  String locale,
  num current,
  num? previous,
) {
  if (previous == null || previous <= 0) return null;
  final percent = (current - previous) / previous * 100;
  final rounded = double.parse(percent.toStringAsFixed(1));
  final text =
      '${rounded > 0
          ? '+'
          : rounded < 0
          ? '−'
          : ''}'
      '${formatDecimal(rounded.abs(), locale, maxDecimals: 1)}%';
  return _delta(l10n, rounded.sign.toInt(), text);
}

/// Zmiana liczby jako [StatDelta], np. „+2”.
StatDelta countDelta(AppLocalizations l10n, int current, int previous) {
  final diff = current - previous;
  final text = diff == 0 ? '0' : '${diff > 0 ? '+' : '−'}${diff.abs()}';
  return _delta(l10n, diff.sign, text);
}

StatDelta _delta(AppLocalizations l10n, int direction, String text) =>
    StatDelta(
      direction: direction,
      text: text,
      semantics: switch (direction) {
        1 => l10n.progressDeltaUp(text),
        -1 => l10n.progressDeltaDown(text),
        _ => l10n.progressDeltaSame,
      },
    );

/// Postęp jednego ćwiczenia w zakresie dat: najlepszy wynik ze zmianą
/// w okresie, najlepsza seria, liczba treningów, objętość i wykresy.
/// Zakładka Progres i zakładka „Wykresy” ekranu ćwiczenia.
class ExerciseProgressSection extends ConsumerWidget {
  const ExerciseProgressSection({
    required this.performances,
    required this.range,
    super.key,
  });

  /// Wykonania ćwiczenia od najnowszego (cała historia).
  final List<({LocalDate date, SessionExercise exercise})> performances;
  final DateRange range;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toString();
    final unit =
        ref.watch(appSettingsProvider).value?.weightUnit ?? WeightUnit.kg;
    final progress = exerciseProgress(performances, range);
    final metric = progress.metric;
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    if (metric == null) return Text(l10n.progressNoMetric, style: muted);

    String value(double v) => switch (metric) {
      ExerciseMetric.e1rm => formatEstimate(v, unit, locale),
      ExerciseMetric.maxReps => '${v.round()} ${l10n.workoutUnitReps}',
      ExerciseMetric.maxDuration => formatClock(v.round()),
    };
    String axis(double v) => switch (metric) {
      ExerciseMetric.e1rm => formatDecimal(
        gramsToDisplay(v.round(), unit),
        locale,
        maxDecimals: 0,
      ),
      ExerciseMetric.maxReps => formatDecimal(v, locale, maxDecimals: 0),
      ExerciseMetric.maxDuration => formatClock(v.round()),
    };
    final metricLabel = switch (metric) {
      ExerciseMetric.e1rm => l10n.progressE1rm,
      ExerciseMetric.maxReps => l10n.progressMaxReps,
      ExerciseMetric.maxDuration => l10n.progressMaxDuration,
    };
    final change = progress.changePercent;
    final trend = progress.trend;
    final inRangePerformances = [
      for (final p in performances)
        if (inRange(p.date, range)) p,
    ];
    final volume = metric == ExerciseMetric.e1rm
        ? volumeTrend(inRangePerformances)
        : const <ChartPoint>[];
    final recentVolume = volume.length > 12
        ? volume.sublist(volume.length - 12)
        : volume;
    Widget noData() => Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.m),
      child: Text(l10n.progressNoData, style: muted),
    );
    final first = trend.isEmpty ? null : trend.first.date;
    double dayOf(LocalDate d) => DateTime.utc(d.year, d.month, d.day)
        .difference(DateTime.utc(first!.year, first.month, first.day))
        .inDays
        .toDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        StatGrid(
          tiles: [
            StatTile(
              label: metricLabel,
              value: progress.best == null ? '—' : value(progress.best!),
            ),
            StatTile(
              label: l10n.progressChange,
              value: change == null
                  ? '—'
                  : percentDelta(
                      l10n,
                      locale,
                      trend.last.value,
                      trend.first.value,
                    )!.text,
            ),
            StatTile(
              label: l10n.progressBestSet,
              value: _bestSet(l10n, progress.bestSet, metric, unit, locale),
            ),
            StatTile(
              label: l10n.progressExerciseWorkouts,
              value: '${progress.workouts}',
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.m),
        if (metric == ExerciseMetric.e1rm)
          TermTitle(
            metricLabel,
            terms: const [
              GlossaryTerm.oneRepMax,
              GlossaryTerm.estimatedOneRepMax,
            ],
            style: theme.textTheme.titleMedium,
          )
        else
          Text(metricLabel, style: theme.textTheme.titleMedium),
        const SizedBox(height: AppSpacing.s),
        if (trend.length < 2)
          noData()
        else
          TrendLineChart(
            spots: [for (final p in trend) (x: dayOf(p.date), y: p.value)],
            xLabel: (x) => axisDate(first!.addDays(x.round()), locale),
            yLabel: axis,
            tooltip: (i) =>
                '${axisDate(trend[i].date, locale)} · ${value(trend[i].value)}',
            semanticLabel: l10n.chartSemantics(
              metricLabel,
              trend.length,
              value(trend.last.value),
            ),
          ),
        if (metric == ExerciseMetric.e1rm) ...[
          const SizedBox(height: AppSpacing.l),
          TermTitle(
            l10n.progressVolume,
            terms: const [GlossaryTerm.volume],
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.s),
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
      ],
    );
  }

  static String _bestSet(
    AppLocalizations l10n,
    SessionSet? set,
    ExerciseMetric metric,
    WeightUnit unit,
    String locale,
  ) {
    if (set == null) return '—';
    return switch (metric) {
      ExerciseMetric.e1rm =>
        '${formatWeight(set.weightG ?? 0, unit, locale)} × ${set.reps ?? 0}',
      ExerciseMetric.maxReps => '${set.reps ?? 0} ${l10n.workoutUnitReps}',
      ExerciseMetric.maxDuration => formatClock(set.durationS ?? 0),
    };
  }
}
