import 'package:flutter_test/flutter_test.dart';
import 'package:reptrack/features/assistant/domain/assistant.dart';

void main() {
  group('normalizeServerUrl', () {
    test('dopisuje schemat i domyślny port Ollamy', () {
      expect(
        normalizeServerUrl(' 192.168.1.10 '),
        Uri.parse('http://192.168.1.10:11434'),
      );
      expect(
        normalizeServerUrl('http://10.0.2.2:8080/api/'),
        Uri.parse('http://10.0.2.2:8080'),
      );
      expect(
        normalizeServerUrl('http://ollama.local'),
        Uri.parse('http://ollama.local:11434'),
      );
    });

    test('https bez portu łączy się na 443, nie na port Ollamy', () {
      expect(
        normalizeServerUrl('https://ollama.example.com'),
        Uri.parse('https://ollama.example.com'),
      );
      expect(normalizeServerUrl('https://ollama.example.com')!.port, 443);
      expect(normalizeServerUrl('https://ollama.example.com:8443')!.port, 8443);
    });

    test('odrzuca tekst, który nie jest adresem', () {
      expect(normalizeServerUrl(''), isNull);
      expect(normalizeServerUrl('ftp://host'), isNull);
      expect(normalizeServerUrl('http://'), isNull);
    });
  });

  group('http tylko w sieci domowej i Tailscale', () {
    test('adresy lokalne', () {
      for (final host in [
        'localhost',
        '127.0.0.1',
        '10.0.2.2',
        '172.16.0.5',
        '172.31.255.1',
        '192.168.1.7',
        '169.254.10.1',
        '100.66.165.22',
        'komputer',
        'pc.local',
        'pc.tail1234.ts.net',
        '::1',
        'fe80::1',
        'fd7a:115c:a1e0::1',
      ]) {
        expect(isLocalNetworkHost(host), isTrue, reason: host);
      }
    });

    test('adresy publiczne', () {
      for (final host in [
        '8.8.8.8',
        '172.32.0.1',
        '100.128.0.1',
        '192.169.0.1',
        'example.com',
        'ollama.moja-domena.pl',
        '2001:db8::1',
      ]) {
        expect(isLocalNetworkHost(host), isFalse, reason: host);
      }
    });

    test('https zawsze, http tylko lokalnie', () {
      expect(isAllowedServer(Uri.parse('http://192.168.1.7:11434')), isTrue);
      expect(isAllowedServer(Uri.parse('https://example.com')), isTrue);
      expect(isAllowedServer(Uri.parse('http://example.com:11434')), isFalse);
      expect(
        () => requireAllowedServer(Uri.parse('http://8.8.8.8:11434')),
        throwsA(
          isA<AssistantException>().having(
            (e) => e.kind,
            'kind',
            AssistantFailureKind.insecure,
          ),
        ),
      );
    });
  });

  test('pickModel: zapisany, jeśli serwer go ma, inaczej pierwszy', () {
    expect(pickModel(['a', 'b'], 'b'), 'b');
    expect(pickModel(['a', 'b'], 'c'), 'a');
    expect(pickModel(['a'], null), 'a');
    expect(pickModel([], 'a'), isNull);
  });

  test('stripThinking usuwa bloki rozumowania, także niezamknięte', () {
    expect(stripThinking('<think>liczę</think>\n\nWynik: 5'), 'Wynik: 5');
    expect(stripThinking('Wynik<think>jeszcze'), 'Wynik');
    expect(stripThinking('Bez bloków'), 'Bez bloków');
  });
}
