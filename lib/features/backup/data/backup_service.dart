import 'dart:convert';
import 'dart:io';

import 'package:collection/collection.dart';

import '../../../core/domain/clock.dart';
import '../domain/backup_summary.dart';
import '../domain/backup_validation.dart';
import 'backup_store.dart';

/// Kopia zapasowa całych danych (ADR 0008): eksport do pliku JSON
/// i przywracanie w trybie „zastąp wszystko”.
final class BackupService {
  BackupService(
    this._store,
    this._clock,
    this._appVersion,
    this._saveSafetyCopy,
  );

  final BackupStore _store;
  final Clock _clock;
  final String _appVersion;

  /// Zapisuje kopię bieżących danych przed przywróceniem (zob.
  /// [SafetyCopies]).
  final Future<void> Function(String json) _saveSafetyCopy;

  /// Pełna kopia jako tekst JSON (czytelny, z wcięciami).
  Future<String> exportJson() async =>
      const JsonEncoder.withIndent(' ')
          .convert(await _store.exportAll(appVersion: _appVersion));

  /// Nazwa pliku kopii, np. `reptrack-kopia-2026-10-19.json`.
  String fileName() {
    final now = _clock.nowUtc().toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    return 'reptrack-kopia-${now.year}-${two(now.month)}-${two(now.day)}.json';
  }

  /// Odczyt i walidacja pliku przed przywróceniem. Rzuca
  /// [BackupInvalidException] albo [BackupTooNewException].
  PreparedRestore prepare(String text) {
    final backup = readBackup(text);
    return PreparedRestore._(backup, summarizeBackup(backup));
  }

  /// Zapisuje bieżące dane jako kopię bezpieczeństwa, a potem zastępuje je
  /// danymi z [restore] w jednej transakcji.
  Future<void> restore(PreparedRestore restore) async {
    await _saveSafetyCopy(await exportJson());
    await _store.replaceAll(restore._backup);
  }
}

/// Kopie bezpieczeństwa sprzed przywrócenia w katalogu aplikacji
/// (`files/kopie`, poza Android Auto Backup). Trzyma [kept] najnowszych.
final class SafetyCopies {
  SafetyCopies(this._directory, this._clock, {this.kept = 5});

  final Future<Directory> Function() _directory;
  final Clock _clock;
  final int kept;

  Future<void> save(String json) async {
    final directory = await _directory();
    await directory.create(recursive: true);
    final stamp = _clock.nowUtc().toIso8601String().replaceAll(':', '-');
    await File(
      '${directory.path}${Platform.pathSeparator}'
      'przed-przywroceniem-$stamp.json',
    ).writeAsString(json);
    final copies = directory
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.json'))
        .sortedBy((f) => f.path)
        .reversed;
    for (final old in copies.skip(kept)) {
      await old.delete();
    }
  }
}

/// Zweryfikowana kopia gotowa do przywrócenia, z podsumowaniem do
/// potwierdzenia przez użytkownika.
final class PreparedRestore {
  const PreparedRestore._(this._backup, this.summary);

  final Map<String, Object?> _backup;
  final BackupSummary summary;
}
