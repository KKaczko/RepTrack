/// Zawartość kopii do potwierdzenia przed przywróceniem.
final class BackupSummary {
  const BackupSummary({
    required this.exportedAt,
    required this.appVersion,
    required this.workouts,
    required this.templates,
    required this.ownExercises,
    required this.hasActiveWorkout,
  });

  final DateTime exportedAt;
  final String? appVersion;

  /// Zakończone treningi (bez usuniętych).
  final int workouts;

  /// Szablony (bez usuniętych).
  final int templates;

  /// Własne ćwiczenia użytkownika (bez usuniętych).
  final int ownExercises;

  /// Kopia zawiera trwający trening.
  final bool hasActiveWorkout;
}

/// Podsumowanie kopii zweryfikowanej przez `readBackup` (czas eksportu
/// jest sprawdzony, więc odczyt nie zawiedzie).
BackupSummary summarizeBackup(Map<String, Object?> backup) {
  List<Map<String, Object?>> rows(String table) =>
      (backup[table]! as List).cast<Map<String, Object?>>();
  bool live(Map<String, Object?> row) => row['deletedAt'] == null;
  final sessions = rows('workoutSessions').where(live);
  return BackupSummary(
    exportedAt: DateTime.parse(backup['exportedAt']! as String),
    appVersion: backup['appVersion'] as String?,
    workouts: sessions.where((s) => s['status'] == 'completed').length,
    templates: rows('templates').where(live).length,
    ownExercises: rows('exercises')
        .where((e) => live(e) && e['source'] == 'user')
        .length,
    hasActiveWorkout: sessions.any((s) => s['status'] == 'active'),
  );
}
