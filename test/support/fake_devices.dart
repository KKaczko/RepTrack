import 'package:reptrack/core/platform/device_services.dart';
import 'package:reptrack/core/platform/rest_notifications.dart';

/// Strefa czasowa telefonu w testach.
final class FixedTimeZone implements DeviceTimeZone {
  const FixedTimeZone([this.zone = 'Europe/Warsaw']);

  final String zone;

  @override
  Future<String> current() async => zone;
}

/// Zapamiętuje stan blokady wygaszania ekranu.
final class FakeScreenAwake implements ScreenAwake {
  bool enabled = false;

  @override
  Future<void> setEnabled({required bool enabled}) async =>
      this.enabled = enabled;
}

/// Zapamiętuje zaplanowaną przerwę zamiast pokazywać powiadomienia.
final class FakeRestNotifications implements RestNotifications {
  DateTime? endsAt;
  String? nextName;
  int cancelCount = 0;
  int permissionRequests = 0;
  bool exactAllowed = true;
  int exactRequests = 0;

  @override
  Future<void> initialize() async {}

  @override
  Future<void> startRest({
    required DateTime endsAt,
    required String nextName,
  }) async {
    this.endsAt = endsAt;
    this.nextName = nextName;
  }

  @override
  Future<void> cancelRest() async {
    endsAt = null;
    nextName = null;
    cancelCount++;
  }

  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    return true;
  }

  @override
  Future<bool> exactAlarmsAllowed() async => exactAllowed;

  @override
  Future<void> requestExactAlarms() async => exactRequests++;
}
