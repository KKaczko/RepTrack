import 'dart:ui';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/timezone.dart' as tz;

import '../l10n/generated/app_localizations.dart';

/// Przypomnienie o treningu z planu (ADR 0015): chwila i treningi.
typedef PlanReminder = ({DateTime at, List<String> workouts});

/// Przypomnienia o treningach z planu. Przybliżone alarmy systemu
/// (bez prośby o dokładne), na najbliższe dni.
abstract interface class PlanReminders {
  /// Zastępuje wszystkie przypomnienia podanymi (najwyżej [maxReminders]).
  Future<void> schedule(List<PlanReminder> reminders);

  /// Prosi o zgodę na powiadomienia (Android 13+). Zwraca, czy są dozwolone.
  Future<bool> requestPermission();
}

/// Najwięcej zaplanowanych przypomnień (stałe id powiadomień).
const maxReminders = 14;

/// Wersja bez efektów, do testów i platform bez powiadomień.
final class NoopPlanReminders implements PlanReminders {
  const NoopPlanReminders();

  @override
  Future<void> schedule(List<PlanReminder> reminders) async {}

  @override
  Future<bool> requestPermission() async => true;
}

/// Przypomnienia przez `flutter_local_notifications`. Wtyczkę inicjuje
/// [LocalRestNotifications] w bootstrapie; tu dochodzi własny kanał.
final class LocalPlanReminders implements PlanReminders {
  LocalPlanReminders([FlutterLocalNotificationsPlugin? plugin])
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;

  /// Id powiadomień 100…113, poza id timera przerwy.
  static const _firstId = 100;
  static const _channel = 'plan_reminders';

  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  AppLocalizations get _l10n {
    final code = PlatformDispatcher.instance.locale.languageCode;
    final supported = AppLocalizations.supportedLocales.any(
      (l) => l.languageCode == code,
    );
    return lookupAppLocalizations(Locale(supported ? code : 'pl'));
  }

  @override
  Future<void> schedule(List<PlanReminder> reminders) async {
    final l10n = _l10n;
    await _android?.createNotificationChannel(
      AndroidNotificationChannel(
        _channel,
        l10n.notifChannelPlan,
        importance: Importance.defaultImportance,
      ),
    );
    for (var i = 0; i < maxReminders; i++) {
      await _plugin.cancel(id: _firstId + i);
    }
    for (final (i, reminder) in reminders.take(maxReminders).indexed) {
      await _plugin.zonedSchedule(
        id: _firstId + i,
        title: l10n.notifPlanTitle,
        body: l10n.notifPlanBody(reminder.workouts.join(', ')),
        scheduledDate: tz.TZDateTime.from(reminder.at.toUtc(), tz.UTC),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            _channel,
            l10n.notifChannelPlan,
            category: AndroidNotificationCategory.reminder,
          ),
        ),
      );
    }
  }

  @override
  Future<bool> requestPermission() async =>
      await _android?.requestNotificationsPermission() ?? true;
}

/// Nadpisywany w `bootstrap` implementacją z powiadomieniami.
final planRemindersProvider = Provider<PlanReminders>(
  (ref) => const NoopPlanReminders(),
);
