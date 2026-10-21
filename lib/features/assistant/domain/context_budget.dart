import 'assistant.dart';

/// Kontekst modelu w tokenach (`num_ctx` Ollamy): dane treningowe, rozmowa
/// i odpowiedź.
const assistantContextTokens = 8192;

/// Część kontekstu zostawiona na odpowiedź modelu.
const assistantReplyReserve = 2048;

/// Ostrożny szacunek liczby tokenów: polski tekst ma ok. 3 znaków na token,
/// więc szacunek raczej zawyża.
int estimateTokens(String text) => (text.length / 3).ceil();

/// Wiadomości do wysłania w budżecie [contextTokens] minus [reserve].
///
/// Instrukcja systemowa to pierwszy wariant z [systemVariants] (od
/// najpełniejszego), który mieści się razem z ostatnim pytaniem. Potem
/// dochodzą najnowsze wcześniejsze tury, dopóki się mieszczą, więc
/// najpierw odpadają najstarsze tury, a dopiero potem dane. Ostatnie pytanie
/// zostaje zawsze. Gdy nic się nie mieści, idzie ostatni (najkrótszy)
/// wariant i samo pytanie.
List<ChatMessage> fitAssistantMessages({
  required Iterable<String> systemVariants,
  required List<ChatMessage> turns,
  int contextTokens = assistantContextTokens,
  int reserve = assistantReplyReserve,
}) {
  assert(turns.isNotEmpty, 'Brak pytania');
  final budget = contextTokens - reserve;
  final last = turns.last;
  String? shortest;
  for (final system in systemVariants) {
    shortest = system;
    var used = estimateTokens(system) + estimateTokens(last.content);
    if (used > budget) continue;
    var start = turns.length - 1;
    while (start > 0) {
      final cost = estimateTokens(turns[start - 1].content);
      if (used + cost > budget) break;
      used += cost;
      start--;
    }
    // Rozmowa po instrukcji zaczyna się od pytania użytkownika.
    while (start < turns.length - 1 && turns[start].role != ChatRole.user) {
      start++;
    }
    return [(role: ChatRole.system, content: system), ...turns.sublist(start)];
  }
  return [(role: ChatRole.system, content: shortest ?? ''), last];
}
