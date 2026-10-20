import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../core/domain/clock.dart';
import '../domain/backup_format.dart';

/// Odczyt i zastąpienie całej bazy w formacie kopii (ADR 0008). Działa na
/// surowych kolumnach schematu v1 według opisu w `backup_format.dart`,
/// niezależnie od encji domeny.
final class BackupStore {
  BackupStore(this._db, this._clock);

  final AppDatabase _db;
  final Clock _clock;

  /// Pełna kopia: wszystkie wiersze, także zarchiwizowane i usunięte,
  /// oraz ustawienia.
  Future<Map<String, Object?>> exportAll({required String appVersion}) async {
    final backup = <String, Object?>{
      'format': backupFormatId,
      'formatVersion': backupFormatVersion,
      'appVersion': appVersion,
      'exportedAt': _iso(_clock.nowUtc().millisecondsSinceEpoch),
      'units': const {
        'weight': 'g',
        'distance': 'm',
        'duration': 's',
        'effort': 'tenths',
        'time': 'ISO 8601 UTC',
      },
    };
    for (final table in backupTables) {
      final rows = await _db
          .customSelect('SELECT * FROM ${table.sql} ORDER BY id')
          .get();
      backup[table.json] = [
        for (final row in rows)
          {
            for (final field in table.fields)
              field.json: _toJson(field, row.data[field.column]),
          },
      ];
    }
    final settings = await _db
        .customSelect('SELECT * FROM settings ORDER BY key')
        .get();
    backup[backupSettingsKey] = [
      for (final row in settings)
        {
          'key': row.read<String>('key'),
          'value': jsonDecode(row.read<String>('value')),
          'updatedAt': _iso(row.read<int>('updated_at')),
        },
    ];
    return backup;
  }

  /// Zastępuje wszystkie dane zawartością zweryfikowanej kopii w jednej
  /// transakcji: przy błędzie baza zostaje bez zmian.
  Future<void> replaceAll(
    Map<String, Object?> backup,
  ) => _db.transaction(() async {
    final tables = {for (final t in _db.allTables) t.actualTableName: t};
    for (final table in backupTables.reversed) {
      await _db.customStatement('DELETE FROM ${table.sql}');
    }
    await _db.customStatement('DELETE FROM settings');
    for (final table in backupTables) {
      final columns = table.fields.map((f) => f.column).join(', ');
      final marks = List.filled(table.fields.length, '?').join(', ');
      for (final row
          in (backup[table.json]! as List).cast<Map<String, Object?>>()) {
        await _db.customInsert(
          'INSERT INTO ${table.sql} ($columns) VALUES ($marks)',
          variables: [
            for (final field in table.fields) _toSql(field, row[field.json]),
          ],
          updates: {tables[table.sql]!},
        );
      }
    }
    for (final entry
        in (backup[backupSettingsKey]! as List).cast<Map<String, Object?>>()) {
      await _db.customInsert(
        'INSERT INTO settings (key, value, updated_at) VALUES (?, ?, ?)',
        variables: [
          Variable.withString(entry['key']! as String),
          Variable.withString(jsonEncode(entry['value'])),
          Variable.withInt(_millis(entry['updatedAt']! as String)),
        ],
        updates: {_db.settings},
      );
    }
  });

  static Object? _toJson(BackupField field, Object? value) {
    if (value == null) return null;
    return switch (field.type) {
      BackupFieldType.time => _iso(value as int),
      BackupFieldType.boolean => value == 1 || value == true,
      BackupFieldType.textList ||
      BackupFieldType.codeList => jsonDecode(value as String),
      _ => value,
    };
  }

  static Variable<Object> _toSql(BackupField field, Object? value) {
    if (value == null) return const Variable(null);
    return switch (field.type) {
      BackupFieldType.time => Variable.withInt(_millis(value as String)),
      BackupFieldType.boolean => Variable.withBool(value as bool),
      BackupFieldType.integer => Variable.withInt(value as int),
      BackupFieldType.textList ||
      BackupFieldType.codeList => Variable.withString(jsonEncode(value)),
      _ => Variable.withString(value as String),
    };
  }

  static String _iso(int millis) => DateTime.fromMillisecondsSinceEpoch(
    millis,
    isUtc: true,
  ).toIso8601String();

  static int _millis(String iso) => DateTime.parse(iso).millisecondsSinceEpoch;
}
