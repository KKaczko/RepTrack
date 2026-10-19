import '../../progress/domain/metrics.dart';
import 'workout_session.dart';

/// Próba utworzenia drugiej aktywnej sesji.
final class ActiveSessionExistsException implements Exception {
  const ActiveSessionExistsException();

  @override
  String toString() => 'ActiveSessionExistsException';
}

abstract interface class WorkoutRepository {
  /// Aktywna sesja z ćwiczeniami i seriami albo null.
  Stream<WorkoutSession?> watchActive();

  Future<WorkoutSession?> findActive();

  Future<WorkoutSession?> findById(String id);

  /// Zapisuje całą sesję w jednej transakcji. Ćwiczenia i serie, których nie
  /// ma już w [session], są miękko usuwane. Rzuca
  /// [ActiveSessionExistsException], gdy inna sesja jest już aktywna.
  Future<void> save(WorkoutSession session);

  /// Porzuca sesję: status `discarded` i miękkie usunięcie.
  Future<void> discard(String sessionId);

  /// Zatwierdzone serie ćwiczenia z ostatniej zakończonej sesji, w której
  /// występuje (niezależnie od szablonu, ADR 0006). Pusta lista, gdy brak.
  Future<List<SessionSet>> lastCompletedSets(
    String exerciseId, {
    String? excludeSessionId,
  });

  /// Wszystkie zatwierdzone serie podanych ćwiczeń z zakończonych sesji,
  /// z trybem obciążenia z chwili wykonania (do rekordów).
  Future<Map<String, List<PerformedSet>>> completedSetsFor(
    Set<String> exerciseIds, {
    String? excludeSessionId,
  });
}
