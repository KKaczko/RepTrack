import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../domain/assistant.dart';
import 'assistant_client.dart';

/// Klient API Ollamy (`/api/version`, `/api/tags`, `/api/chat`) przez
/// `dart:io`, bez dodatkowych pakietów. Sprawdzone na Ollamie 0.40.6.
final class OllamaClient implements AssistantClient {
  OllamaClient({
    this.connectTimeout = const Duration(seconds: 5),
    this.idleTimeout = const Duration(minutes: 3),
  });

  final Duration connectTimeout;

  /// Najdłuższa przerwa między fragmentami odpowiedzi. Duża, bo na słabym
  /// komputerze model długo czyta kontekst przed pierwszym słowem.
  final Duration idleTimeout;

  /// Kontekst modelu w tokenach: dane treningowe i rozmowa.
  static const contextTokens = 8192;

  @override
  Future<String> version(Uri server) async {
    final json = await _getJson(server.resolve('/api/version'));
    final version = json['version'];
    if (version is! String) {
      throw const AssistantException(AssistantFailureKind.server);
    }
    return version;
  }

  @override
  Future<List<String>> models(Uri server) async {
    final json = await _getJson(server.resolve('/api/tags'));
    final models = json['models'];
    if (models is! List) {
      throw const AssistantException(AssistantFailureKind.server);
    }
    // Od najmniejszego: domyślny (pierwszy) model odpowiada najszybciej.
    final named = [
      for (final m in models)
        if (m case {'name': final String name}) (name: name, size: m['size']),
    ]..sort((a, b) => _size(a.size).compareTo(_size(b.size)));
    return [for (final m in named) m.name];
  }

  @override
  Stream<String> chat(
    Uri server, {
    required String model,
    required List<ChatMessage> messages,
  }) {
    final client = _client();
    HttpClientRequest? request;
    StreamSubscription<String>? lines;
    late final StreamController<String> controller;

    /// Błąd kończy odpowiedź.
    void fail(Object error) {
      if (controller.isClosed) return;
      controller.addError(_mapError(error));
      unawaited(controller.close());
    }

    Future<void> start() async {
      try {
        request = await client.postUrl(server.resolve('/api/chat'));
        request!.headers.contentType = ContentType.json;
        request!.write(
          jsonEncode({
            'model': model,
            'stream': true,
            'think': false,
            'options': {'num_ctx': contextTokens},
            'messages': [
              for (final m in messages)
                {'role': m.role.name, 'content': m.content},
            ],
          }),
        );
        final response = await request!.close();
        if (response.statusCode != HttpStatus.ok) {
          throw await _failure(response);
        }
        lines = response
            .transform(utf8.decoder)
            .transform(const LineSplitter())
            .timeout(idleTimeout)
            .listen(
              (line) {
                if (line.trim().isEmpty || controller.isClosed) return;
                final Object? json;
                try {
                  json = jsonDecode(line);
                } on FormatException catch (error) {
                  fail(error);
                  return;
                }
                if (json is! Map) return;
                if (json['error'] case final String error) {
                  fail(AssistantException(AssistantFailureKind.server, error));
                  return;
                }
                if (json['message'] case {'content': final String content}
                    when content.isNotEmpty) {
                  controller.add(content);
                }
                if (json['done'] == true) unawaited(controller.close());
              },
              onError: fail,
              onDone: () {
                if (!controller.isClosed) unawaited(controller.close());
              },
            );
      } on Object catch (error) {
        fail(error);
      }
    }

    controller = StreamController<String>(
      onListen: () => unawaited(start()),
      // Najpierw zerwanie połączenia: anulowanie samego strumienia
      // odpowiedzi czeka na serwer.
      onCancel: () {
        request?.abort();
        client.close(force: true);
        unawaited(lines?.cancel());
      },
    );
    return controller.stream;
  }

  static num _size(Object? size) => size is num ? size : double.infinity;

  HttpClient _client() => HttpClient()..connectionTimeout = connectTimeout;

  Future<Map<String, Object?>> _getJson(Uri uri) async {
    final client = _client();
    try {
      final request = await client.getUrl(uri);
      final response = await request.close().timeout(connectTimeout * 2);
      if (response.statusCode != HttpStatus.ok) {
        throw await _failure(response);
      }
      final body = await response
          .transform(utf8.decoder)
          .join()
          .timeout(connectTimeout * 2);
      final json = jsonDecode(body);
      if (json is! Map<String, Object?>) {
        throw const AssistantException(AssistantFailureKind.server);
      }
      return json;
    } on Object catch (error) {
      throw _mapError(error);
    } finally {
      client.close(force: true);
    }
  }

  /// Błąd HTTP z treścią `{"error": "..."}`; 404 przy czacie to brak modelu.
  static Future<AssistantException> _failure(
    HttpClientResponse response,
  ) async {
    String? detail;
    try {
      final json = jsonDecode(await response.transform(utf8.decoder).join());
      if (json is Map && json['error'] is String) {
        detail = json['error'] as String;
      }
    } on Object {
      // Treść bez JSON-a: zostaje sam kod.
    }
    return AssistantException(
      response.statusCode == HttpStatus.notFound
          ? AssistantFailureKind.modelMissing
          : AssistantFailureKind.server,
      detail ?? 'HTTP ${response.statusCode}',
    );
  }

  static AssistantException _mapError(Object error) => switch (error) {
    AssistantException() => error,
    TimeoutException() => const AssistantException(
      AssistantFailureKind.timeout,
    ),
    SocketException() || HttpException() => AssistantException(
      AssistantFailureKind.unreachable,
      error.toString(),
    ),
    FormatException() => const AssistantException(AssistantFailureKind.server),
    _ => AssistantException(AssistantFailureKind.server, error.toString()),
  };
}
