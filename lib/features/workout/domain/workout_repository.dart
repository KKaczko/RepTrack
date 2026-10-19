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
}
