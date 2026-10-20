import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../../app/app_info.dart';
import '../../../core/database/database_providers.dart';
import 'backup_service.dart';
import 'backup_store.dart';

/// Zapis kopii bezpieczeństwa sprzed przywrócenia (`files/kopie`, poza
/// Android Auto Backup). Testy podmieniają go na zapis w pamięci.
final safetyCopyWriterProvider = Provider<Future<void> Function(String json)>(
  (ref) => SafetyCopies(
    () async => Directory(
      '${(await getApplicationSupportDirectory()).path}'
      '${Platform.pathSeparator}kopie',
    ),
    ref.watch(clockProvider),
  ).save,
);

final backupServiceProvider = Provider<BackupService>(
  (ref) => BackupService(
    BackupStore(ref.watch(appDatabaseProvider), ref.watch(clockProvider)),
    ref.watch(clockProvider),
    appVersionName,
    ref.watch(safetyCopyWriterProvider),
  ),
);
