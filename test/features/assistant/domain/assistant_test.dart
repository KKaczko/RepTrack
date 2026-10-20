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
        normalizeServerUrl('https://ollama.local'),
        Uri.parse('https://ollama.local:11434'),
      );
    });

    test('odrzuca tekst, który nie jest adresem', () {
      expect(normalizeServerUrl(''), isNull);
      expect(normalizeServerUrl('ftp://host'), isNull);
      expect(normalizeServerUrl('http://'), isNull);
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
