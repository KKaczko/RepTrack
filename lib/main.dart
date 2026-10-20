import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'app/bootstrap.dart';
import 'core/database/database_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final container = await bootstrap();
  // Checkpoint WAL przy przejściu w tło (Android Auto Backup, ADR 0008).
  // Nasłuchiwacz rejestruje się w WidgetsBinding i żyje razem z aplikacją.
  AppLifecycleListener(
    onHide: () => unawaited(container.read(appDatabaseProvider).checkpoint()),
  );
  runApp(
    UncontrolledProviderScope(container: container, child: const RepTrackApp()),
  );
}
