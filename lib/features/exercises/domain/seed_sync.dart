import 'exercise.dart';

/// Wynik planowania synchronizacji wbudowanej biblioteki z bazą.
final class SeedSyncPlan {
  const SeedSyncPlan({
    required this.inserts,
    required this.updates,
    required this.skippedUserModified,
  });

  /// Nowe ćwiczenia z seeda.
  final List<Exercise> inserts;

  /// Ćwiczenia wbudowane zmienione w nowszej wersji seeda.
  final List<Exercise> updates;

  /// Identyfikatory pominięte, bo użytkownik je zmodyfikował.
  final List<String> skippedUserModified;

  bool get isEmpty => inserts.isEmpty && updates.isEmpty;
}

/// Planuje aktualizację biblioteki wbudowanej (ADR 0005, docs/data-model.md).
///
/// * Ćwiczenie z seeda, którego nie ma w bazie, jest dodawane.
/// * Ćwiczenie zmodyfikowane przez użytkownika (`userModified`) nigdy nie jest
///   nadpisywane.
/// * Pozostałe są aktualizowane, gdy ich rewizja w seedzie (`seedVersion`)
///   jest nowsza niż zapisana. Zachowany zostaje stan archiwizacji.
/// * Nic nie jest usuwane, także ćwiczenia, których nie ma już w seedzie.
SeedSyncPlan planSeedSync({
  required Iterable<Exercise> existing,
  required Iterable<Exercise> seed,
}) {
  final byId = {for (final e in existing) e.id: e};
  final inserts = <Exercise>[];
  final updates = <Exercise>[];
  final skipped = <String>[];

  for (final entry in seed) {
    final current = byId[entry.id];
    if (current == null) {
      inserts.add(entry);
    } else if (current.userModified) {
      skipped.add(entry.id);
    } else if ((current.seedVersion ?? 0) < (entry.seedVersion ?? 0)) {
      updates.add(entry.copyWith(archivedAt: current.archivedAt));
    }
  }
  return SeedSyncPlan(
    inserts: inserts,
    updates: updates,
    skippedUserModified: skipped,
  );
}
