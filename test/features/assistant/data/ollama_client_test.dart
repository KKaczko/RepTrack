import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:reptrack/features/assistant/data/ollama_client.dart';
import 'package:reptrack/features/assistant/domain/assistant.dart';

/// Lokalny serwer udający Ollamę; [handler] obsługuje każde zapytanie.
Future<(HttpServer, Uri)> _serve(
  Future<void> Function(HttpRequest request) handler,
) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  server.listen((request) {
    // Bez buforowania, jak Ollama: każdy fragment od razu do klienta.
    request.response.bufferOutput = false;
    unawaited(handler(request));
  });
  return (server, Uri.parse('http://127.0.0.1:${server.port}'));
}

Future<void> _json(HttpRequest request, Object body, {int status = 200}) async {
  request.response
    ..statusCode = status
    ..headers.contentType = ContentType.json
    ..write(jsonEncode(body));
  await request.response.close();
}

void main() {
  final client = OllamaClient(idleTimeout: const Duration(seconds: 2));

  test('wersja i lista modeli', () async {
    final (server, uri) = await _serve((request) async {
      switch (request.uri.path) {
        case '/api/version':
          await _json(request, {'version': '0.40.6'});
        case '/api/tags':
          await _json(request, {
            // Ollama nie sortuje po rozmiarze.
            'models': [
              {'name': 'qwen3.8:27b', 'size': 17000000000},
              {'name': 'qwen3.5:4b', 'size': 3400000000},
            ],
          });
      }
    });
    addTearDown(server.close);

    expect(await client.version(uri), '0.40.6');
    expect(await client.models(uri), ['qwen3.5:4b', 'qwen3.8:27b']);
  });

  test(
    'czat: zapytanie z wyłączonym myśleniem i strumień fragmentów',
    () async {
      Map<String, Object?>? sent;
      final (server, uri) = await _serve((request) async {
        sent = jsonDecode(
          await utf8.decoder.bind(request).join(),
        ) as Map<String, Object?>;
        request.response.headers.contentType = ContentType(
          'application',
          'x-ndjson',
          charset: 'utf-8',
        );
        for (final (text, done) in [
          ('Dzień', false),
          (' dobry', false),
          ('', true),
        ]) {
          request.response.writeln(
            jsonEncode({
              'message': {'role': 'assistant', 'content': text},
              'done': done,
            }),
          );
          await request.response.flush();
        }
        await request.response.close();
      });
      addTearDown(server.close);

      final chunks = await client
          .chat(
            uri,
            model: 'qwen3.5:4b',
            messages: const [
              (role: ChatRole.system, content: 'Po polsku.'),
              (role: ChatRole.user, content: 'Cześć'),
            ],
          )
          .toList();

      expect(chunks.join(), 'Dzień dobry');
      expect(sent!['model'], 'qwen3.5:4b');
      expect(sent!['stream'], isTrue);
      expect(sent!['think'], isFalse);
      expect(sent!['messages'], [
        {'role': 'system', 'content': 'Po polsku.'},
        {'role': 'user', 'content': 'Cześć'},
      ]);
    },
  );

  test('brak modelu: 404 z komunikatem serwera', () async {
    final (server, uri) = await _serve(
      (request) =>
          _json(request, {'error': "model 'x' not found"}, status: 404),
    );
    addTearDown(server.close);

    await expectLater(
      client.chat(uri, model: 'x', messages: const []),
      emitsError(
        isA<AssistantException>()
            .having((e) => e.kind, 'kind', AssistantFailureKind.modelMissing)
            .having((e) => e.detail, 'detail', "model 'x' not found"),
      ),
    );
  });

  test('błąd w trakcie strumienia kończy odpowiedź', () async {
    final (server, uri) = await _serve((request) async {
      request.response
        ..writeln(
          jsonEncode({
            'message': {'content': 'Po'},
            'done': false,
          }),
        )
        ..writeln(jsonEncode({'error': 'out of memory'}));
      await request.response.close();
    });
    addTearDown(server.close);

    final events = <Object>[];
    final done = Completer<void>();
    client
        .chat(uri, model: 'm', messages: const [])
        .listen(events.add, onError: events.add, onDone: done.complete);
    await done.future;

    expect(events.first, 'Po');
    expect(
      events.last,
      isA<AssistantException>().having(
        (e) => e.detail,
        'detail',
        'out of memory',
      ),
    );
  });

  test('serwer nie odpowiada: brak połączenia', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final uri = Uri.parse('http://127.0.0.1:${server.port}');
    await server.close(force: true);

    await expectLater(
      client.version(uri),
      throwsA(
        isA<AssistantException>().having(
          (e) => e.kind,
          'kind',
          AssistantFailureKind.unreachable,
        ),
      ),
    );
  });

  test('przerwa dłuższa niż limit: timeout', () async {
    final (server, uri) = await _serve((request) async {
      request.response.writeln(
        jsonEncode({
          'message': {'content': 'Za'},
          'done': false,
        }),
      );
      await request.response.flush();
      await Future<void>.delayed(const Duration(seconds: 4));
      await request.response.close();
    });
    addTearDown(() => server.close(force: true));

    final events = <Object>[];
    final done = Completer<void>();
    client
        .chat(uri, model: 'm', messages: const [])
        .listen(events.add, onError: events.add, onDone: done.complete);
    await done.future;

    expect(
      events.last,
      isA<AssistantException>().having(
        (e) => e.kind,
        'kind',
        AssistantFailureKind.timeout,
      ),
    );
  });

  test('anulowanie: koniec fragmentów i błędów od razu', () async {
    final (server, uri) = await _serve((request) async {
      try {
        for (var i = 0; i < 40; i++) {
          request.response.writeln(
            jsonEncode({
              'message': {'content': 'A'},
              'done': false,
            }),
          );
          await Future<void>.delayed(const Duration(milliseconds: 50));
        }
        await request.response.close();
      } on Object {
        // Klient zerwał połączenie.
      }
    });
    addTearDown(() => server.close(force: true));

    final events = <Object>[];
    final first = Completer<void>();
    final subscription = client
        .chat(uri, model: 'm', messages: const [])
        .listen((chunk) {
          events.add(chunk);
          if (!first.isCompleted) first.complete();
        }, onError: events.add);
    await first.future;
    await subscription.cancel().timeout(const Duration(seconds: 1));
    final count = events.length;
    await Future<void>.delayed(const Duration(milliseconds: 400));

    expect(events, hasLength(count));
    expect(events.whereType<AssistantException>(), isEmpty);
  });
}
