/// Asystent AI (ADR 0014): rozmowa z modelem językowym na serwerze Ollama
/// właściciela. Model dostaje dane policzone przez aplikację i niczego nie
/// zapisuje.
library;

enum ChatRole { system, user, assistant }

/// Wiadomość rozmowy.
typedef ChatMessage = ({ChatRole role, String content});

/// Port Ollamy, gdy adres go nie podaje.
const ollamaDefaultPort = 11434;

enum AssistantFailureKind {
  /// Nie ustawiono adresu serwera albo modelu.
  notConfigured,

  /// Serwer nie odpowiada (wyłączony PC, inna sieć, zapora).
  unreachable,

  /// Serwer nie ma wybranego modelu.
  modelMissing,

  /// Odpowiedź nie przyszła w czasie.
  timeout,

  /// Inny błąd serwera albo nieczytelna odpowiedź.
  server,
}

final class AssistantException implements Exception {
  const AssistantException(this.kind, [this.detail]);

  final AssistantFailureKind kind;

  /// Komunikat serwera, jeśli był.
  final String? detail;

  @override
  String toString() => 'AssistantException($kind, $detail)';
}

/// Adres serwera z tekstu wpisanego przez użytkownika: dopisuje `http://`
/// i domyślny port Ollamy, usuwa ścieżkę. Null dla tekstu, który nie jest
/// adresem.
Uri? normalizeServerUrl(String input) {
  final text = input.trim();
  if (text.isEmpty) return null;
  final withScheme = text.contains('://') ? text : 'http://$text';
  final uri = Uri.tryParse(withScheme);
  if (uri == null ||
      !(uri.scheme == 'http' || uri.scheme == 'https') ||
      uri.host.isEmpty) {
    return null;
  }
  return Uri(
    scheme: uri.scheme,
    host: uri.host,
    port: uri.hasPort ? uri.port : ollamaDefaultPort,
  );
}

/// Model do użycia: zapisany w ustawieniach, jeśli serwer go ma, a inaczej
/// pierwszy z listy (najmniejszy). Null, gdy serwer nie ma żadnego modelu.
String? pickModel(List<String> available, String? configured) {
  if (configured != null && available.contains(configured)) return configured;
  return available.isEmpty ? null : available.first;
}

/// Tekst odpowiedzi bez bloków rozumowania `<think>…</think>`, które
/// niektóre modele wysyłają mimo wyłączonego myślenia. Niezamknięty blok
/// (odpowiedź w trakcie) jest ukrywany do końca.
String stripThinking(String text) {
  final withoutClosed = text.replaceAll(RegExp(r'<think>[\s\S]*?</think>'), '');
  final open = withoutClosed.indexOf('<think>');
  return (open < 0 ? withoutClosed : withoutClosed.substring(0, open))
      .trimLeft();
}
