import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/tokens.dart';

/// Wykresy jednej serii (progres): linia trendu i słupki. Jedna seria nie
/// potrzebuje legendy; tytuł nad wykresem mówi, co jest na nim. Znaczniki
/// mają kolor akcentu (kontrast ≥ 3:1 w obu motywach), siatka i osie są
/// stonowane, a dotknięcie pokazuje wartość w dymku.

/// Kolor serii: wypełnienie akcentem w ciemnym motywie, ciemniejszy akcent
/// tekstowy w jasnym (żółtozielony na bieli ma za mały kontrast).
Color _seriesColor(BuildContext context) {
  final theme = Theme.of(context);
  return theme.brightness == Brightness.dark
      ? context.appColors.accentFill
      : theme.colorScheme.primary;
}

/// Punkt wykresu: [x] w jednostkach osi (np. dni od pierwszego treningu).
typedef ChartSpot = ({double x, double y});

/// Linia trendu z kropkami, delikatnym wypełnieniem i dymkiem po dotknięciu.
class TrendLineChart extends StatelessWidget {
  const TrendLineChart({
    required this.spots,
    required this.xLabel,
    required this.yLabel,
    required this.tooltip,
    required this.semanticLabel,
    super.key,
  });

  final List<ChartSpot> spots;
  final String Function(double x) xLabel;
  final String Function(double y) yLabel;

  /// Treść dymka dla punktu o indeksie z [spots].
  final String Function(int index) tooltip;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _seriesColor(context);
    final surface = theme.colorScheme.surface;
    final axis = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
      fontFeatures: AppTheme.tabularFigures,
    );
    final ys = spots.map((s) => s.y);
    final yAxis = _niceAxis(ys.reduce(min), ys.reduce(max));
    final minX = spots.first.x;
    final maxX = max(spots.last.x, minX + 1);

    return Semantics(
      label: semanticLabel,
      excludeSemantics: true,
      child: SizedBox(
        height: 200,
        child: LineChart(
          LineChartData(
            minX: minX,
            maxX: maxX,
            minY: yAxis.min,
            maxY: yAxis.max,
            borderData: FlBorderData(show: false),
            gridData: FlGridData(
              drawVerticalLine: false,
              horizontalInterval: yAxis.step,
              getDrawingHorizontalLine: (_) =>
                  FlLine(color: theme.colorScheme.outline, strokeWidth: 1),
            ),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(),
              rightTitles: const AxisTitles(),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 44,
                  interval: yAxis.step,
                  getTitlesWidget: (value, meta) => SideTitleWidget(
                    meta: meta,
                    child: Text(yLabel(value), style: axis),
                  ),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 28,
                  interval: max(1, (maxX - minX) / 3),
                  getTitlesWidget: (value, meta) => SideTitleWidget(
                    meta: meta,
                    child: Text(xLabel(value), style: axis),
                  ),
                ),
              ),
            ),
            lineTouchData: LineTouchData(
              touchTooltipData: LineTouchTooltipData(
                getTooltipColor: (_) => context.appColors.surfaceRaised,
                fitInsideHorizontally: true,
                fitInsideVertically: true,
                getTooltipItems: (touched) => [
                  for (final spot in touched)
                    LineTooltipItem(
                      tooltip(spot.spotIndex),
                      theme.textTheme.bodySmall!.copyWith(
                        color: theme.colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            ),
            lineBarsData: [
              LineChartBarData(
                spots: [for (final s in spots) FlSpot(s.x, s.y)],
                color: color,
                barWidth: 2,
                isStrokeCapRound: true,
                isStrokeJoinRound: true,
                dotData: FlDotData(
                  getDotPainter: (spot, percent, bar, index) =>
                      FlDotCirclePainter(
                        radius: 4,
                        color: color,
                        strokeWidth: 2,
                        strokeColor: surface,
                      ),
                ),
                belowBarData: BarAreaData(
                  show: true,
                  color: color.withValues(alpha: 0.1),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Słupki jednej serii, np. treningi w tygodniu albo objętość na trening.
class ValueBarChart extends StatelessWidget {
  const ValueBarChart({
    required this.values,
    required this.xLabel,
    required this.yLabel,
    required this.tooltip,
    required this.semanticLabel,
    this.integerAxis = false,
    super.key,
  });

  final List<double> values;
  final String Function(int index) xLabel;
  final String Function(double y) yLabel;
  final String Function(int index) tooltip;
  final String semanticLabel;

  /// Oś z liczbami całkowitymi (np. liczba treningów).
  final bool integerAxis;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _seriesColor(context);
    final axis = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
      fontFeatures: AppTheme.tabularFigures,
    );
    final top = values.isEmpty ? 1.0 : values.reduce(max);
    final yAxis = _niceAxis(0, top);
    final interval = integerAxis
        ? max(1.0, yAxis.step.ceilToDouble())
        : yAxis.step;
    final maxY = integerAxis
        ? max(2.0, (top / interval).ceil() * interval)
        : yAxis.max;
    final labelEvery = max(1, (values.length / 6).ceil());

    return Semantics(
      label: semanticLabel,
      excludeSemantics: true,
      child: SizedBox(
        height: 180,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final slot = (constraints.maxWidth - 44) / max(1, values.length);
            final width = min(24.0, max(4.0, slot - AppSpacing.xs));
            return BarChart(
              BarChartData(
                maxY: maxY,
                borderData: FlBorderData(show: false),
                gridData: FlGridData(
                  drawVerticalLine: false,
                  horizontalInterval: interval,
                  getDrawingHorizontalLine: (_) =>
                      FlLine(color: theme.colorScheme.outline, strokeWidth: 1),
                ),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(),
                  rightTitles: const AxisTitles(),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 44,
                      interval: interval,
                      getTitlesWidget: (value, meta) => SideTitleWidget(
                        meta: meta,
                        child: Text(yLabel(value), style: axis),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      getTitlesWidget: (value, meta) {
                        // Co [labelEvery] słupków, licząc od ostatniego,
                        // żeby etykiety nie nachodziły na siebie.
                        final i = value.toInt();
                        if ((values.length - 1 - i) % labelEvery != 0) {
                          return const SizedBox.shrink();
                        }
                        return SideTitleWidget(
                          meta: meta,
                          child: Text(xLabel(i), style: axis),
                        );
                      },
                    ),
                  ),
                ),
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => context.appColors.surfaceRaised,
                    fitInsideHorizontally: true,
                    fitInsideVertically: true,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) =>
                        BarTooltipItem(
                          tooltip(groupIndex),
                          theme.textTheme.bodySmall!.copyWith(
                            color: theme.colorScheme.onSurface,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                  ),
                ),
                barGroups: [
                  for (final (i, value) in values.indexed)
                    BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: value,
                          color: color,
                          width: width,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(4),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Zakres osi o okrągłym kroku, obejmujący [low]–[high] z odrobiną
/// zapasu: (min, max, krok siatki).
({double min, double max, double step}) _niceAxis(double low, double high) {
  final span = high - low;
  final raw = (span <= 0 ? max(1.0, high.abs() * 0.2) : span * 1.2) / 4;
  final magnitude = pow(10, (log(raw) / ln10).floor()).toDouble();
  final step = [
    1.0,
    2.0,
    2.5,
    5.0,
    10.0,
  ].map((m) => m * magnitude).firstWhere((s) => s >= raw);
  final lower = max(0.0, ((low - step / 2) / step).floor() * step);
  var upper = lower + step * 4;
  while (upper < high + step / 4) {
    upper += step;
  }
  return (min: lower, max: upper, step: step);
}
