import 'package:intl/intl.dart';

import '../../../core/domain/local_date.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../domain/plan_schedule.dart';

/// Teksty planu (także dla Startu i asystenta).
extension PlanLabels on AppLocalizations {
  String planStatus(PlanStatus status) => switch (status) {
    PlanStatus.done => planStatusDone,
    PlanStatus.replaced => planStatusReplaced,
    PlanStatus.missed => planStatusMissed,
    PlanStatus.today => planStatusToday,
    PlanStatus.upcoming => planStatusUpcoming,
  };
}

DateTime _dateTime(LocalDate date) => DateTime(date.year, date.month, date.day);

String _capitalized(String text) =>
    text.isEmpty ? text : text[0].toUpperCase() + text.substring(1);

/// Nazwa dnia tygodnia (1 = poniedziałek), np. „Poniedziałek”.
String weekdayName(int weekday, String locale) => _capitalized(
  DateFormat.EEEE(locale).format(DateTime(2026, 10, 11 + weekday)),
);

/// Skrót dnia tygodnia do nagłówka siatki (1 = poniedziałek), np. „Pn”.
String weekdayShort(AppLocalizations l10n, int weekday) =>
    l10n.planWeekdaysShort.split(',')[weekday - 1].trim();

/// Dzień z nazwą, np. „Środa, 14 października”.
String longDate(LocalDate date, String locale) =>
    _capitalized(DateFormat.MMMMEEEEd(locale).format(_dateTime(date)));

/// Miesiąc z rokiem do nagłówka kalendarza, np. „Październik 2026”.
String monthTitle(LocalDate month, String locale) =>
    _capitalized(DateFormat.yMMMM(locale).format(_dateTime(month)));

/// Zakres tygodnia, np. „12–18 paź”.
String weekRange(LocalDate start, String locale) {
  final end = start.addDays(6);
  final day = DateFormat.d(locale);
  final dayMonth = DateFormat.MMMd(locale);
  return start.month == end.month
      ? '${day.format(_dateTime(start))}–${dayMonth.format(_dateTime(end))}'
      : '${dayMonth.format(_dateTime(start))} – '
            '${dayMonth.format(_dateTime(end))}';
}
