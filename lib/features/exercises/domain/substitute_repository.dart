import 'substitutes.dart';

/// Przypięte zamienniki ćwiczeń (ADR 0016). Para działa w obie strony.
abstract interface class SubstituteRepository {
  /// Wszystkie przypięte pary, w kolejności przypinania.
  Stream<List<SubstitutePin>> watch();

  /// Przypina [substituteId] jako zamiennik [exerciseId]; para już
  /// przypięta (w którąkolwiek stronę) zostaje bez zmian.
  Future<void> pin(String exerciseId, String substituteId);

  /// Odpina parę niezależnie od kierunku.
  Future<void> unpin(String exerciseId, String substituteId);
}
