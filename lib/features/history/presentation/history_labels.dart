import 'package:intl/intl.dart';

import '../../../core/domain/local_date.dart';
import '../../../core/domain/units.dart';
import '../../../core/l10n/formatters.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../exercises/domain/exercise.dart';
import '../../workout/domain/session_editing.dart';
import '../../workout/domain/session_summary.dart';
import '../../workout/domain/workout_session.dart';

/// Etykiety historii treningów.
extension HistoryLabels on AppLocalizations {
  /// Czas trwania, np. „47 min” albo „1 h 05 min”.
  String duration(Duration duration) {
    final minutes = duration.inMinutes;
    if (minutes < 60) return durationMinutes(minutes);
    return durationHoursMinutes(minutes ~/ 60, minutes % 60);
  }

  /// „pon., 19 paź · 18:05” w strefie zapisanej przy starcie treningu.
  String sessionWhen(WorkoutSession session, String locale) {
    final time = localTimeFor(session.startedAt, session.timeZone);
    return sessionDateTime(
      shortDate(session.localDate, locale),
      '${time.hour.toString().padLeft(2, '0')}:'
      '${time.minute.toString().padLeft(2, '0')}',
    );
  }

  /// Podsumowanie, np. „47 min · 12 serii · 4520 kg”.
  String sessionSummary(
    WorkoutSession session,
    WeightUnit unit,
    String locale,
  ) {
    final summary = summarizeSession(
      session,
      session.endedAt ?? session.startedAt,
    );
    return [
      duration(summary.duration),
      setCount(summary.completedSets),
      if (summary.volumeG > 0) formatVolume(summary.volumeG, unit, locale),
    ].join(' · ');
  }

  /// Zatwierdzone serie ćwiczenia, np. „80×10 · 80×9 · 77,5×8”.
  String exerciseSets(
    SessionExercise exercise,
    WeightUnit unit,
    String locale,
  ) {
    final m = exercise.measurementSnapshot;
    return [
      for (final set in sortedSets(exercise))
        if (set.isCompleted)
          ?formatSetValues(
            unit: unit,
            locale: locale,
            weightG: m.weight ? set.weightG : null,
            reps: m.reps ? set.reps : null,
            durationS: m.duration ? set.durationS : null,
            distanceM: m.distance ? set.distanceM : null,
            metersUnit: workoutUnitMeters,
          ),
    ].join(' · ');
  }

  /// Nazwa ćwiczenia: aktualna z katalogu, a gdy ćwiczenia nie ma, snapshot
  /// z chwili treningu (ADR 0006).
  String exerciseName(
    SessionExercise exercise,
    Map<String, Exercise> catalog,
  ) => catalog[exercise.exerciseId]?.name ?? exercise.exerciseNameSnapshot;
}

/// Data treningu, np. „pon., 19 paź”.
String shortDate(LocalDate date, String locale) =>
    DateFormat.MMMEd(locale).format(DateTime(date.year, date.month, date.day));

/// Miesiąc i rok nagłówka listy, np. „październik 2026”.
String monthHeader(LocalDate date, String locale) =>
    DateFormat.yMMMM(locale).format(DateTime(date.year, date.month));

/// Krótka data osi wykresu, np. „19.10”.
String axisDate(LocalDate date, String locale) =>
    DateFormat.Md(locale).format(DateTime(date.year, date.month, date.day));
