import 'package:flutter_test/flutter_test.dart';
import 'package:reptrack/features/assistant/domain/assistant.dart';
import 'package:reptrack/features/assistant/domain/context_budget.dart';

ChatMessage _user(String text) => (role: ChatRole.user, content: text);
ChatMessage _bot(String text) => (role: ChatRole.assistant, content: text);

int _tokens(List<ChatMessage> messages) =>
    messages.fold(0, (sum, m) => sum + estimateTokens(m.content));

void main() {
  const budget = assistantContextTokens - assistantReplyReserve;

  test('krótka rozmowa: pełny przegląd i wszystkie tury', () {
    final turns = [_user('a'), _bot('b'), _user('c')];
    final messages = fitAssistantMessages(
      systemVariants: ['pełny', 'krótki'],
      turns: turns,
    );

    expect(messages.first, (role: ChatRole.system, content: 'pełny'));
    expect(messages.skip(1), turns);
  });

  test('długa rozmowa: odpadają najstarsze tury, pytanie zostaje', () {
    final long = 'x' * 6000;
    final turns = [
      for (var i = 0; i < 6; i++) ...[_user('$i$long'), _bot('$i$long')],
      _user('ostatnie pytanie'),
    ];
    final messages = fitAssistantMessages(
      systemVariants: ['dane' * 1000],
      turns: turns,
    );

    expect(_tokens(messages), lessThanOrEqualTo(budget));
    expect(messages.last.content, 'ostatnie pytanie');
    expect(messages[1].role, ChatRole.user);
    expect(messages.length, lessThan(turns.length + 1));
  });

  test('za duże dane: krótszy wariant przeglądu przed obcięciem pytania', () {
    final huge = 'n' * (budget * 3 + 10);
    final variants = <String>[];
    Iterable<String> lazy() sync* {
      variants.add('pełny');
      yield huge;
      variants.add('krótki');
      yield 'krótki przegląd';
      variants.add('najkrótszy');
      yield 'najkrótszy';
    }

    final messages = fitAssistantMessages(
      systemVariants: lazy(),
      turns: [_user('pytanie')],
    );

    expect(messages.first.content, 'krótki przegląd');
    // Kolejne warianty nie są liczone, gdy wcześniejszy się mieści.
    expect(variants, ['pełny', 'krótki']);
  });

  test('nic się nie mieści: najkrótszy wariant i samo pytanie', () {
    final huge = 'n' * (budget * 3 + 10);
    final messages = fitAssistantMessages(
      systemVariants: [huge, huge],
      turns: [_user('stare'), _bot('odp'), _user('pytanie')],
    );

    expect(messages.map((m) => m.role), [ChatRole.system, ChatRole.user]);
    expect(messages.last.content, 'pytanie');
  });
}
