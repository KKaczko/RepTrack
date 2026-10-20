import 'package:flutter/material.dart';

import '../../../core/domain/local_date.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../domain/plan_schedule.dart';
import 'plan_labels.dart';

/// Kolor znaczników planu: akcent volt w ciemnym motywie, `primary`
/// w jasnym (ADR 0012, jak serie wykresów).
Color planAccent(BuildContext context) {
  final theme = Theme.of(context);
  return theme.brightness == Brightness.dark
      ? context.appColors.accentFill
      : theme.colorScheme.primary;
}

/// Znacznik dnia w kalendarzu.
enum DayMark { done, planned, missed }

/// Znaczniki dnia: zrobione (także zastępstwa i treningi spoza planu),
/// zaplanowane (dziś i dalej) i pominięte.
List<DayMark> dayMarks(DayOverview overview) => [
  for (final entry in overview.entries)
    switch (entry.status) {
      PlanStatus.done || PlanStatus.replaced => DayMark.done,
      PlanStatus.today || PlanStatus.upcoming => DayMark.planned,
      PlanStatus.missed => DayMark.missed,
    },
  for (final _ in overview.extra) DayMark.done,
];

/// Znacznik: pełne kółko, obwódka albo krzyżyk, więc stan nie zależy tylko
/// od koloru.
class DayMarkIcon extends StatelessWidget {
  const DayMarkIcon(this.mark, {super.key, this.size = 8});

  final DayMark mark;
  final double size;

  @override
  Widget build(BuildContext context) {
    final accent = planAccent(context);
    return switch (mark) {
      DayMark.done => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
      ),
      DayMark.planned => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: accent, width: 1.5),
        ),
      ),
      DayMark.missed => Icon(
        Icons.close_rounded,
        size: size + 4,
        color: Theme.of(context).colorScheme.error,
      ),
    };
  }
}

/// Siatka miesiąca: tygodnie od poniedziałku, dni spoza miesiąca wyciszone.
/// Gest w bok albo strzałki zmieniają miesiąc.
class MonthCalendar extends StatelessWidget {
  const MonthCalendar({
    required this.month,
    required this.today,
    required this.selected,
    required this.overview,
    required this.semantics,
    required this.onSelect,
    required this.onMonth,
    super.key,
  });

  /// Pierwszy dzień wyświetlanego miesiąca.
  final LocalDate month;
  final LocalDate today;
  final LocalDate selected;
  final DayOverview Function(LocalDate date) overview;

  /// Opis dnia dla czytnika ekranu.
  final String Function(DayOverview overview) semantics;
  final ValueChanged<LocalDate> onSelect;

  /// Zmiana miesiąca o -1 albo +1.
  final ValueChanged<int> onMonth;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toString();
    final first = month.startOfWeek;
    final last = monthStart(month, 1).addDays(-1);
    final weeks =
        last.startOfWeek.toDateTime().difference(first.toDateTime()).inDays ~/
            7 +
        1;
    return GestureDetector(
      onHorizontalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;
        if (velocity.abs() > 300) onMonth(velocity < 0 ? 1 : -1);
      },
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                tooltip: l10n.planPrevMonth,
                icon: const Icon(Icons.chevron_left_rounded),
                onPressed: () => onMonth(-1),
              ),
              Expanded(
                child: Text(
                  monthTitle(month, locale),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium,
                ),
              ),
              IconButton(
                tooltip: l10n.planNextMonth,
                icon: const Icon(Icons.chevron_right_rounded),
                onPressed: () => onMonth(1),
              ),
            ],
          ),
          ExcludeSemantics(
            child: Row(
              children: [
                for (var weekday = 1; weekday <= 7; weekday++)
                  Expanded(
                    child: Text(
                      weekdayShort(l10n, weekday),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          for (var week = 0; week < weeks; week++)
            Row(
              children: [
                for (var d = 0; d < 7; d++)
                  Expanded(
                    child: _DayCell(
                      date: first.addDays(week * 7 + d),
                      inMonth: first.addDays(week * 7 + d).month == month.month,
                      today: today,
                      selected: selected,
                      overview: overview(first.addDays(week * 7 + d)),
                      semantics: semantics,
                      onTap: onSelect,
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.date,
    required this.inMonth,
    required this.today,
    required this.selected,
    required this.overview,
    required this.semantics,
    required this.onTap,
  });

  final LocalDate date;
  final bool inMonth;
  final LocalDate today;
  final LocalDate selected;
  final DayOverview overview;
  final String Function(DayOverview overview) semantics;
  final ValueChanged<LocalDate> onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isSelected = date == selected;
    final isToday = date == today;
    final marks = dayMarks(overview);
    return Semantics(
      button: true,
      selected: isSelected,
      label: semantics(overview),
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxs),
        child: Material(
          color: isSelected
              ? theme.colorScheme.secondaryContainer
              : Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.s),
            side: isToday
                ? BorderSide(color: planAccent(context), width: 1.5)
                : BorderSide.none,
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.s),
            onTap: () => onTap(date),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: AppSizes.minTouch),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        '${date.day}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: isToday || isSelected
                              ? FontWeight.w700
                              : FontWeight.w500,
                          fontFeatures: AppTheme.tabularFigures,
                          color: isSelected
                              ? theme.colorScheme.onSecondaryContainer
                              : inMonth
                              ? theme.colorScheme.onSurface
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    SizedBox(
                      height: 12,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          for (final mark in marks.take(3))
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 1,
                              ),
                              child: DayMarkIcon(mark, size: 6),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Legenda znaczników pod kalendarzem.
class PlanLegend extends StatelessWidget {
  const PlanLegend({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final style = Theme.of(context).textTheme.labelMedium
        ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant);
    Widget item(DayMark mark, String label) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        DayMarkIcon(mark),
        const SizedBox(width: AppSpacing.xs),
        Text(label, style: style),
      ],
    );
    return ExcludeSemantics(
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: AppSpacing.l,
        runSpacing: AppSpacing.xs,
        children: [
          item(DayMark.done, l10n.planLegendDone),
          item(DayMark.planned, l10n.planLegendPlanned),
          item(DayMark.missed, l10n.planLegendMissed),
        ],
      ),
    );
  }
}

/// Plakietka stanu treningu z planu (ikona i tekst).
class PlanStatusChip extends StatelessWidget {
  const PlanStatusChip({required this.status, super.key, this.extra = false});

  final PlanStatus? status;

  /// Trening spoza planu.
  final bool extra;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final (icon, label, color) = extra
        ? (Icons.add_task_rounded, l10n.planStatusExtra, planAccent(context))
        : switch (status!) {
            PlanStatus.done => (
              Icons.check_circle_rounded,
              l10n.planStatusDone,
              planAccent(context),
            ),
            PlanStatus.replaced => (
              Icons.swap_horiz_rounded,
              l10n.planStatusReplaced,
              planAccent(context),
            ),
            PlanStatus.missed => (
              Icons.cancel_outlined,
              l10n.planStatusMissed,
              theme.colorScheme.error,
            ),
            PlanStatus.today => (
              Icons.today_rounded,
              l10n.planStatusToday,
              theme.colorScheme.primary,
            ),
            PlanStatus.upcoming => (
              Icons.schedule_rounded,
              l10n.planStatusUpcoming,
              theme.colorScheme.onSurfaceVariant,
            ),
          };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: AppSpacing.xs),
        Flexible(
          child: Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

/// Pierwszy dzień miesiąca daty [date] przesuniętego o [offset] miesięcy.
LocalDate monthStart(LocalDate date, [int offset = 0]) {
  final d = DateTime.utc(date.year, date.month + offset);
  return LocalDate(d.year, d.month, 1);
}

extension on LocalDate {
  DateTime toDateTime() => DateTime.utc(year, month, day);
}
