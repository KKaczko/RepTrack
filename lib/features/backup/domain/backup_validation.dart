import 'dart:convert';

import '../../../core/domain/local_date.dart';
import 'backup_format.dart';

/// Odczyt i walidacja pliku kopii (ADR 0008). Cały plik jest sprawdzany
/// przed jakimkolwiek zapisem do bazy.

/// Plik nie jest kopią RepTrack albo jest uszkodzony.
final class BackupInvalidException implements Exception {
  const BackupInvalidException(this.problems);

  /// Opisy problemów (ścieżka i przyczyna), najwyżej [maxReportedProblems].
  final List<String> problems;

  @override
  String toString() => 'BackupInvalidException(${problems.join('; ')})';
}

/// Plik pochodzi z nowszej wersji aplikacji (wyższa wersja formatu).
final class BackupTooNewException implements Exception {
  const BackupTooNewException(this.formatVersion);

  final int formatVersion;

  @override
  String toString() => 'BackupTooNewException($formatVersion)';
}

/// Najwięcej zgłaszanych problemów: reszta i tak wynika z tych samych błędów.
const maxReportedProblems = 20;

/// Migracja z wersji `n` do `n + 1`.
typedef BackupMigration = Map<String, Object?> Function(
  Map<String, Object?> backup,
);

/// Migracje formatu: klucz to wersja źródłowa. Wersja 1 jest pierwsza, więc
/// lista jest pusta; kolejna wersja formatu dopisuje tu migrację z 1 do 2.
const Map<int, BackupMigration> backupMigrations = {};

/// Odczyt kopii: JSON, rozpoznanie formatu, migracja do bieżącej wersji
/// i pełna walidacja. Zwraca dane w bieżącej wersji formatu.
Map<String, Object?> readBackup(
  String text, {
  Map<int, BackupMigration> migrations = backupMigrations,
  int currentVersion = backupFormatVersion,
}) {
  final Object? decoded;
  try {
    decoded = jsonDecode(text);
  } on FormatException {
    throw const BackupInvalidException(['Plik nie jest poprawnym JSON.']);
  }
  if (decoded is! Map<String, Object?> || decoded['format'] != backupFormatId) {
    throw const BackupInvalidException(['To nie jest plik kopii RepTrack.']);
  }
  final version = decoded['formatVersion'];
  if (version is! int || version < 1) {
    throw const BackupInvalidException(['Brak poprawnej wersji formatu.']);
  }
  if (version > currentVersion) throw BackupTooNewException(version);
  final migrated = migrateBackup(
    decoded,
    from: version,
    to: currentVersion,
    migrations: migrations,
  );
  final problems = validateBackup(migrated);
  if (problems.isNotEmpty) throw BackupInvalidException(problems);
  return migrated;
}

/// Przeprowadza kopię przez kolejne migracje od [from] do [to].
Map<String, Object?> migrateBackup(
  Map<String, Object?> backup, {
  required int from,
  required int to,
  Map<int, BackupMigration> migrations = backupMigrations,
}) {
  var current = backup;
  for (var version = from; version < to; version++) {
    final migration = migrations[version];
    if (migration == null) {
      throw BackupInvalidException([
        'Brak migracji formatu z wersji $version.',
      ]);
    }
    current = migration(current)..['formatVersion'] = version + 1;
  }
  return current;
}

/// Problemy w kopii w bieżącej wersji formatu; pusta lista, gdy plik jest
/// poprawny. Sprawdza typy, kody, zakresy, unikalność identyfikatorów,
/// klucze obce i zasady modelu (pomiar ćwiczenia, jedna aktywna sesja).
List<String> validateBackup(Map<String, Object?> backup) {
  final problems = <String>[];
  void report(String problem) {
    if (problems.length < maxReportedProblems) problems.add(problem);
  }

  final ids = <String, Set<String>>{};
  final rowsByTable = <String, List<Map<String, Object?>>>{};
  for (final table in backupTables) {
    final raw = backup[table.json];
    if (raw is! List) {
      report('${table.json}: brak tablicy.');
      continue;
    }
    final rows = <Map<String, Object?>>[];
    final tableIds = ids[table.json] = <String>{};
    for (final (index, row) in raw.indexed) {
      final path = '${table.json}[$index]';
      if (row is! Map<String, Object?>) {
        report('$path: oczekiwano obiektu.');
        continue;
      }
      rows.add(row);
      for (final field in table.fields) {
        final problem = _checkField(field, row[field.json]);
        if (problem != null) report('$path.${field.json}: $problem');
      }
      final id = row['id'];
      if (id is String && !tableIds.add(id)) {
        report('$path.id: powtórzony identyfikator $id.');
      }
    }
    rowsByTable[table.json] = rows;
  }
  if (problems.isNotEmpty) return problems;

  // Klucze obce: odwołania do istniejących wierszy w pliku.
  for (final table in backupTables) {
    for (final (index, row) in rowsByTable[table.json]!.indexed) {
      for (final field in table.fields) {
        final target = field.references;
        final value = row[field.json];
        if (target == null || value == null) continue;
        if (!ids[target]!.contains(value)) {
          report(
            '${table.json}[$index].${field.json}: brak $target o id $value.',
          );
        }
      }
    }
  }

  for (final (index, row) in rowsByTable['exercises']!.indexed) {
    final measures = [
      row['measureWeight'],
      row['measureReps'],
      row['measureDuration'],
      row['measureDistance'],
    ];
    if (!measures.contains(true)) {
      report('exercises[$index]: ćwiczenie bez żadnego pola pomiaru.');
    }
  }

  final active = rowsByTable['workoutSessions']!.where(
    (s) => s['status'] == 'active' && s['deletedAt'] == null,
  );
  if (active.length > 1) {
    report('workoutSessions: więcej niż jeden aktywny trening.');
  }

  final settings = backup[backupSettingsKey];
  if (settings is! List) {
    report('$backupSettingsKey: brak tablicy.');
  } else {
    final keys = <String>{};
    for (final (index, entry) in settings.indexed) {
      final path = '$backupSettingsKey[$index]';
      if (entry is! Map<String, Object?> || entry['key'] is! String) {
        report('$path: oczekiwano obiektu z kluczem.');
        continue;
      }
      if (!entry.containsKey('value')) report('$path.value: brak wartości.');
      if (_checkTime(entry['updatedAt']) case final problem?) {
        report('$path.updatedAt: $problem');
      }
      if (!keys.add(entry['key']! as String)) {
        report('$path.key: powtórzony klucz ${entry['key']}.');
      }
    }
  }
  return problems;
}

String? _checkField(BackupField field, Object? value) {
  if (value == null) return field.nullable ? null : 'brak wartości.';
  switch (field.type) {
    case BackupFieldType.id || BackupFieldType.text:
      if (value is! String) return 'oczekiwano tekstu.';
      if (field.type == BackupFieldType.id && value.isEmpty) {
        return 'pusty identyfikator.';
      }
    case BackupFieldType.integer:
      if (value is! int) return 'oczekiwano liczby całkowitej.';
      if (field.min case final min? when value < min) return 'mniej niż $min.';
      if (field.max case final max? when value > max) return 'więcej niż $max.';
    case BackupFieldType.boolean:
      if (value is! bool) return 'oczekiwano true albo false.';
    case BackupFieldType.time:
      return _checkTime(value);
    case BackupFieldType.date:
      if (value is! String) return 'oczekiwano daty YYYY-MM-DD.';
      try {
        LocalDate.parse(value);
      } on FormatException {
        return 'niepoprawna data $value.';
      }
    case BackupFieldType.code:
      if (value is! String || !field.codes!.contains(value)) {
        return 'nieznany kod $value.';
      }
    case BackupFieldType.textList || BackupFieldType.codeList:
      if (value is! List || value.any((v) => v is! String)) {
        return 'oczekiwano listy tekstów.';
      }
      if (field.type == BackupFieldType.codeList) {
        final unknown = value.where((v) => !field.codes!.contains(v));
        if (unknown.isNotEmpty) return 'nieznane kody ${unknown.join(', ')}.';
      }
  }
  return null;
}

String? _checkTime(Object? value) {
  if (value is! String) return 'oczekiwano czasu ISO 8601.';
  final parsed = DateTime.tryParse(value);
  if (parsed == null || !parsed.isUtc) return 'niepoprawny czas UTC $value.';
  return null;
}
