import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'assistant_client.dart';
import 'ollama_client.dart';

/// Klient serwera modelu (w testach atrapa).
final assistantClientProvider = Provider<AssistantClient>(
  (ref) => OllamaClient(),
);
