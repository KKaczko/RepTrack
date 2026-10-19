import 'exercise.dart';

/// Ćwiczenia nie można usunąć, bo jest użyte w szablonie lub historii.
/// Takie ćwiczenie można tylko zarchiwizować.
final class ExerciseInUseException implements Exception {
  const ExerciseInUseException(this.exerciseId);

  final String exerciseId;

  @override
  String toString() => 'ExerciseInUseException($exerciseId)';
}

abstract interface class ExerciseRepository {
  /// Katalog ćwiczeń posortowany po nazwie, bez usuniętych.
  Stream<List<Exercise>> watchAll({bool includeArchived = false});

  Future<Exercise?> findById(String id);

  /// Dodaje albo aktualizuje ćwiczenie.
  Future<void> save(Exercise exercise);

  Future<void> setArchived(String id, {required bool archived});

  /// Czy ćwiczenie występuje w szablonie albo w historii.
  Future<bool> isInUse(String id);

  /// Miękko usuwa nieużyte ćwiczenie. Rzuca [ExerciseInUseException], gdy
  /// ćwiczenie jest użyte.
  Future<void> delete(String id);
}
