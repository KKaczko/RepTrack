import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../domain/local_date.dart';

/// Usługi urządzenia za interfejsami, żeby testy mogły je podmienić.

/// Strefa IANA telefonu, zapisywana przy starcie sesji (spec. 4).
abstract interface class DeviceTimeZone {
  Future<String> current();
}

final class PlatformTimeZone implements DeviceTimeZone {
  const PlatformTimeZone();

  @override
  Future<String> current() async {
    try {
      final zone = (await FlutterTimezone.getLocalTimezone()).identifier;
      return isKnownTimeZone(zone) ? zone : 'UTC';
    } on Object {
      return 'UTC';
    }
  }
}

/// „Nie wygaszaj ekranu podczas treningu”.
abstract interface class ScreenAwake {
  Future<void> setEnabled({required bool enabled});
}

final class WakelockScreenAwake implements ScreenAwake {
  const WakelockScreenAwake();

  @override
  Future<void> setEnabled({required bool enabled}) async {
    try {
      await WakelockPlus.toggle(enable: enabled);
    } on Object {
      // Brak blokady wygaszania nie może przerwać treningu.
    }
  }
}

final deviceTimeZoneProvider = Provider<DeviceTimeZone>(
  (ref) => const PlatformTimeZone(),
);

final screenAwakeProvider = Provider<ScreenAwake>(
  (ref) => const WakelockScreenAwake(),
);
