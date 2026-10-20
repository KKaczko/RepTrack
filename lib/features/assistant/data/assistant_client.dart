import '../domain/assistant.dart';

/// Połączenie z serwerem modelu językowego. Błędy jako
/// [AssistantException].
abstract interface class AssistantClient {
  /// Wersja serwera; test połączenia.
  Future<String> version(Uri server);

  /// Modele dostępne na serwerze.
  Future<List<String>> models(Uri server);

  /// Odpowiedź modelu strumieniowana fragmentami. Anulowanie subskrypcji
  /// przerywa zapytanie.
  Stream<String> chat(
    Uri server, {
    required String model,
    required List<ChatMessage> messages,
  });
}
