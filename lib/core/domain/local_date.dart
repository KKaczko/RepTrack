import 'package:meta/meta.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Data kalendarzowa bez czasu i strefy, np. dzień treningu.
@immutable
final class LocalDate implements Comparable<LocalDate> {
  const LocalDate(this.year, this.month, this.day);

  /// Parsuje format `YYYY-MM-DD`.
  factory LocalDate.parse(String iso) {
    final match = _isoPattern.firstMatch(iso);
    if (match == null) {
      throw FormatException('Niepoprawna data lokalna', iso);
    }
    final date = LocalDate(
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      int.parse(match.group(3)!),
    );
    final check = DateTime.utc(date.year, date.month, date.day);
    if (check.month != date.month || check.day != date.day) {
      throw FormatException('Nieistniejąca data', iso);
    }
    return date;
  }

  static final _isoPattern = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');

  final int year;
  final int month;
  final int day;

  /// Dzień tygodnia: 1 = poniedziałek … 7 = niedziela.
  int get weekday => DateTime.utc(year, month, day).weekday;

  /// Poniedziałek tygodnia, do którego należy ta data.
  LocalDate get startOfWeek {
    final d = DateTime.utc(
      year,
      month,
      day,
    ).subtract(Duration(days: weekday - 1));
    return LocalDate(d.year, d.month, d.day);
  }

  LocalDate addDays(int days) {
    final d = DateTime.utc(year, month, day).add(Duration(days: days));
    return LocalDate(d.year, d.month, d.day);
  }

  String toIso() =>
      '${year.toString().padLeft(4, '0')}-'
      '${month.toString().padLeft(2, '0')}-'
      '${day.toString().padLeft(2, '0')}';

  @override
  int compareTo(LocalDate other) {
    if (year != other.year) return year.compareTo(other.year);
    if (month != other.month) return month.compareTo(other.month);
    return day.compareTo(other.day);
  }

  @override
  bool operator ==(Object other) =>
      other is LocalDate &&
      other.year == year &&
      other.month == month &&
      other.day == day;

  @override
  int get hashCode => Object.hash(year, month, day);

  @override
  String toString() => toIso();
}

bool _timeZonesLoaded = false;

/// Ładuje bazę stref IANA. Wywoływane w bootstrapie i w testach; idempotentne.
void ensureTimeZonesLoaded() {
  if (_timeZonesLoaded) return;
  tz_data.initializeTimeZones();
  _timeZonesLoaded = true;
}

/// Czy [ianaZone] jest znaną strefą IANA (np. `Europe/Warsaw`).
bool isKnownTimeZone(String ianaZone) {
  ensureTimeZonesLoaded();
  try {
    tz.getLocation(ianaZone);
    return true;
  } on tz.LocationNotFoundException {
    return false;
  }
}

/// Data lokalna momentu [utc] w strefie [ianaZone].
///
/// Data treningu to lokalna data rozpoczęcia w strefie zapisanej przy starcie
/// sesji, także dla treningu po północy i po zmianie strefy telefonu.
LocalDate localDateFor(DateTime utc, String ianaZone) {
  ensureTimeZonesLoaded();
  final local = tz.TZDateTime.from(utc.toUtc(), tz.getLocation(ianaZone));
  return LocalDate(local.year, local.month, local.day);
}
