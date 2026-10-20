import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';

/// Prosty Markdown odpowiedzi modelu bez dodatkowych pakietów: nagłówki,
/// listy punktowane i numerowane oraz pogrubienie `**tekst**`. Reszta jako
/// zwykły tekst (tabele i kod rzadko pojawiają się w odpowiedziach).
class AssistantMarkdown extends StatelessWidget {
  const AssistantMarkdown(this.text, {super.key});

  final String text;

  static final _bullet = RegExp(r'^\s*[-*•]\s+');
  static final _numbered = RegExp(r'^\s*(\d+)[.)]\s+');
  static final _heading = RegExp(r'^\s*#{1,6}\s+');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final body = theme.textTheme.bodyLarge;
    final blocks = <Widget>[];
    for (final raw in text.trimRight().split('\n')) {
      final line = raw.trimRight();
      if (line.trim().isEmpty) {
        blocks.add(const SizedBox(height: AppSpacing.s));
      } else if (_heading.hasMatch(line)) {
        blocks.add(
          Text.rich(
            _inline(line.replaceFirst(_heading, '')),
            style: theme.textTheme.titleSmall,
          ),
        );
      } else if (_bullet.firstMatch(line) case final match?) {
        blocks.add(_item('•', line.substring(match.end), body));
      } else if (_numbered.firstMatch(line) case final match?) {
        blocks.add(_item('${match[1]}.', line.substring(match.end), body));
      } else {
        blocks.add(Text.rich(_inline(line), style: body));
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: blocks,
    );
  }

  Widget _item(String marker, String content, TextStyle? style) => Padding(
    padding: const EdgeInsets.only(left: AppSpacing.xs, top: AppSpacing.xxs),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 24, child: Text(marker, style: style)),
        Expanded(child: Text.rich(_inline(content), style: style)),
      ],
    ),
  );

  /// Pogrubienia `**…**`; pozostałe gwiazdki zostają w tekście.
  static TextSpan _inline(String text) {
    final spans = <TextSpan>[];
    final bold = RegExp(r'\*\*(.+?)\*\*');
    var start = 0;
    for (final match in bold.allMatches(text)) {
      if (match.start > start) {
        spans.add(TextSpan(text: text.substring(start, match.start)));
      }
      spans.add(
        TextSpan(
          text: match[1],
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      );
      start = match.end;
    }
    if (start < text.length) spans.add(TextSpan(text: text.substring(start)));
    return TextSpan(children: spans);
  }
}
