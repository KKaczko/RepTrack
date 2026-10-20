import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_providers.dart';
import '../../../core/domain/local_date.dart';
import '../../../core/platform/plan_reminders.dart';
import '../../settings/data/settings_providers.dart';
import '../../templates/data/template_providers.dart';
import '../../templates/domain/template.dart';
import '../../workout/data/workout_providers.dart';
import '../../workout/domain/workout_session.dart';
import '../domain/plan.dart';
import '../domain/plan_schedule.dart';
import 'plan_providers.dart';

/// Przypomnienia na najbliższe dni o godzinie [minutes] (czas lokalny
/// telefonu). Pomija godziny, które już minęły, dni bez niezrobionych
/// treningów oraz szablony usunięte i zarchiwizowane.
List<PlanReminder> planReminderList({
  required PlanState plan,
  required List<WorkoutSession> history,
  required List<Template> templates,
  required DateTime now,
  required int minutes,
}) {
  final today = LocalDate(now.year, now.month, now.day);
  final byId = {for (final t in templates) t.id: t};
  return [
    for (final day in reminderDays(plan, sessionsByDate(history), today))
      if (DateTime(
            day.date.year,
            day.date.month,
            day.date.day,
            minutes ~/ 60,
            minutes % 60,
          )
          case final at when at.isAfter(now))
        if ([
              for (final id in day.templateIds)
                if (byId[id] case final t? when !t.isArchived) t.name,
            ]
            case final names when names.isNotEmpty)
          (at: at.toUtc(), workouts: names),
  ];
}

/// Przelicza przypomnienia po każdej zmianie planu, ustawień, szablonów
/// i zakończonych treningów. Obserwuje go [RepTrackApp]; zaplanowane
/// alarmy zostają w systemie także po zamknięciu aplikacji.
final planReminderSyncProvider = Provider<void>((ref) {
  final settings = ref.watch(appSettingsProvider).value;
  final plan = ref.watch(planProvider).value;
  final history = ref.watch(completedSessionsProvider).value;
  final templates = ref.watch(templatesProvider).value;
  if (settings == null ||
      plan == null ||
      history == null ||
      templates == null) {
    return;
  }
  final reminders = settings.planReminders
      ? planReminderList(
          plan: plan,
          history: history,
          templates: templates,
          now: ref.read(clockProvider).nowUtc().toLocal(),
          minutes: settings.planReminderMinutes,
        )
      : const <PlanReminder>[];
  unawaited(
    ref
        .read(planRemindersProvider)
        .schedule(reminders)
        .catchError(
          (Object error, StackTrace stack) => FlutterError.reportError(
            FlutterErrorDetails(
              exception: error,
              stack: stack,
              library: 'reptrack plan',
            ),
          ),
        ),
  );
});
