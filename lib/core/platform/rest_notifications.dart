import 'dart:ui';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/timezone.dart' as tz;

import '../domain/local_date.dart';
import '../l10n/generated/app_localizations.dart';

/// Powiadomienia przerwy (ADR 0009): trwałe odliczanie z systemowym
/// chronometrem oraz zaplanowany alarm końca. Dokładny alarm tylko za zgodą
/// użytkownika (`SCHEDULE_EXACT_ALARM`), w przeciwnym razie przybliżony.
abstract interface class RestNotifications {
  Future<void> initialize();

  /// Pokazuje odliczanie i planuje alarm na [endsAt].
  Future<void> startRest({required DateTime endsAt, required String nextName});

  Future<void> cancelRest();

  /// Prosi o zgodę na powiadomienia (Android 13+). Zwraca, czy są dozwolone.
  Future<bool> requestPermission();

  /// Czy dozwolone są dokładne alarmy.
  Future<bool> exactAlarmsAllowed();

  /// Otwiera systemową zgodę na dokładne alarmy.
  Future<void> requestExactAlarms();
}

/// Wersja bez efektów, do testów i platform bez powiadomień.
final class NoopRestNotifications implements RestNotifications {
  const NoopRestNotifications();

  @override
  Future<void> initialize() async {}

  @override
  Future<void> startRest({
    required DateTime endsAt,
    required String nextName,
  }) async {}

  @override
  Future<void> cancelRest() async {}

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<bool> exactAlarmsAllowed() async => true;

  @override
  Future<void> requestExactAlarms() async {}
}

final class LocalRestNotifications implements RestNotifications {
  LocalRestNotifications([FlutterLocalNotificationsPlugin? plugin])
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;

  static const _countdownId = 1;
  static const _endId = 2;
  static const _countdownChannel = 'rest_countdown';
  static const _endChannel = 'rest_end';

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
  Future<void> initialize() async {
    ensureTimeZonesLoaded();
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_stat_timer'),
      ),
    );
    final l10n = _l10n;
    await _android?.createNotificationChannel(
      AndroidNotificationChannel(
        _countdownChannel,
        l10n.notifChannelRest,
        importance: Importance.low,
        playSound: false,
        enableVibration: false,
        showBadge: false,
      ),
    );
    await _android?.createNotificationChannel(
      AndroidNotificationChannel(
        _endChannel,
        l10n.notifChannelRestEnd,
        importance: Importance.high,
      ),
    );
  }

  @override
  Future<void> startRest({
    required DateTime endsAt,
    required String nextName,
  }) async {
    await cancelRest();
    final l10n = _l10n;
    final remaining = endsAt.difference(DateTime.now().toUtc());
    if (remaining <= Duration.zero) return;
    await _plugin.show(
      id: _countdownId,
      title: l10n.notifRestTitle,
      body: l10n.notifRestBody(nextName),
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _countdownChannel,
          l10n.notifChannelRest,
          importance: Importance.low,
          priority: Priority.low,
          ongoing: true,
          autoCancel: false,
          onlyAlertOnce: true,
          showWhen: true,
          when: endsAt.millisecondsSinceEpoch,
          usesChronometer: true,
          chronometerCountDown: true,
          timeoutAfter: remaining.inMilliseconds,
          category: AndroidNotificationCategory.stopwatch,
        ),
      ),
    );
    final exact = await exactAlarmsAllowed();
    await _plugin.zonedSchedule(
      id: _endId,
      title: l10n.notifRestEndTitle,
      body: l10n.notifRestEndBody(nextName),
      scheduledDate: tz.TZDateTime.from(endsAt.toUtc(), tz.UTC),
      androidScheduleMode: exact
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _endChannel,
          l10n.notifChannelRestEnd,
          importance: Importance.high,
          priority: Priority.high,
          category: AndroidNotificationCategory.alarm,
        ),
      ),
    );
  }

  @override
  Future<void> cancelRest() async {
    await _plugin.cancel(id: _countdownId);
    await _plugin.cancel(id: _endId);
  }

  @override
  Future<bool> requestPermission() async =>
      await _android?.requestNotificationsPermission() ?? true;

  @override
  Future<bool> exactAlarmsAllowed() async =>
      await _android?.canScheduleExactNotifications() ?? true;

  @override
  Future<void> requestExactAlarms() async {
    await _android?.requestExactAlarmsPermission();
  }
}

/// Nadpisywany w `bootstrap` implementacją z powiadomieniami.
final restNotificationsProvider = Provider<RestNotifications>(
  (ref) => const NoopRestNotifications(),
);
