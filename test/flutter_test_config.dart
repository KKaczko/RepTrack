import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

/// Globalna konfiguracja testów: stuknięcie w element zasłonięty przez inny
/// widżet (np. snackbar nad przyciskiem) jest błędem, a nie ostrzeżeniem.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  WidgetController.hitTestWarningShouldBeFatal = true;
  await testMain();
}
