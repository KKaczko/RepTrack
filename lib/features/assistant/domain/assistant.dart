/// Asystent AI (ADR 0014): rozmowa z modelem językowym na serwerze Ollama
/// właściciela. Model dostaje dane policzone przez aplikację i niczego nie
/// zapisuje.
library;

enum ChatRole { system, user, assistant }

/// Wiadomość rozmowy.
typedef ChatMessage = ({ChatRole role, String content});

/// Port Ollamy, gdy adres `http` go nie podaje (`https` bez portu: 443).
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

  /// Adres publiczny bez szyfrowania (`http`); wymagany `https`.
  insecure,
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
    port: uri.hasPort
        ? uri.port
        : uri.scheme == 'https'
        ? 443
        : ollamaDefaultPort,
  );
}

/// Czy [host] jest w sieci domowej, w Tailscale albo na tym samym
/// urządzeniu. Tylko z takimi adresami aplikacja łączy się bez szyfrowania.
bool isLocalNetworkHost(String host) {
  final name = host.toLowerCase();
  if (name == 'localhost' ||
      name.endsWith('.localhost') ||
      name.endsWith('.local') ||
      name.endsWith('.ts.net')) {
    return true;
  }
  if (name.contains(':')) {
    // IPv6: pętla zwrotna, adresy lokalne łącza (fe80::/10)
    // i prywatne (fc00::/7, w tym Tailscale fd7a:115c:a1e0::/48).
    return name == '::1' ||
        RegExp('^fe[89ab]').hasMatch(name) ||
        RegExp('^f[cd]').hasMatch(name);
  }
  final parts = name.split('.');
  final octets = [for (final p in parts) int.tryParse(p)];
  final isIpv4 =
      parts.length == 4 && octets.every((o) => o != null && o >= 0 && o <= 255);
  if (!isIpv4) {
    // Nazwa jednoczłonowa (np. „komputer”) działa tylko w sieci lokalnej.
    return parts.length == 1;
  }
  final [a, b, ...] = octets.nonNulls.toList();
  return a == 10 ||
      a == 127 ||
      (a == 172 && b >= 16 && b <= 31) ||
      (a == 192 && b == 168) ||
      (a == 169 && b == 254) ||
      (a == 100 && b >= 64 && b <= 127);
}

/// Czy wolno łączyć się z [server]: `https` zawsze, `http` tylko w sieci
/// domowej i Tailscale, bo asystent wysyła dane treningowe i notatki.
bool isAllowedServer(Uri server) =>
    server.scheme == 'https' ||
    (server.scheme == 'http' && isLocalNetworkHost(server.host));

/// Rzuca [AssistantFailureKind.insecure] dla niedozwolonego adresu.
void requireAllowedServer(Uri server) {
  if (!isAllowedServer(server)) {
    throw const AssistantException(AssistantFailureKind.insecure);
  }
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
