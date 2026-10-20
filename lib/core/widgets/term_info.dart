import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../domain/glossary.dart';
import '../l10n/generated/app_localizations.dart';
import '../l10n/glossary_labels.dart';
import '../theme/tokens.dart';

/// Trasa słowniczka (`AppRoutes.glossary`).
const glossaryPath = '/glossary';

/// Ikonka ⓘ przy pojęciu: arkusz z opisem [terms] i przejściem do
/// słowniczka.
class TermInfoButton extends StatelessWidget {
  const TermInfoButton(this.terms, {super.key});

  final List<GlossaryTerm> terms;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return IconButton(
      icon: const Icon(Icons.info_outline_rounded, size: 20),
      color: Theme.of(context).colorScheme.onSurfaceVariant,
      tooltip: l10n.glossaryInfoTooltip(l10n.glossaryTermTitle(terms.first)),
      onPressed: () => unawaited(showTermInfo(context, terms)),
    );
  }
}

/// Tytuł z ikonką ⓘ tuż za tekstem.
class TermTitle extends StatelessWidget {
  const TermTitle(this.text, {required this.terms, this.style, super.key});

  final String text;
  final List<GlossaryTerm> terms;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Flexible(child: Text(text, style: style)),
      TermInfoButton(terms),
    ],
  );
}

/// Arkusz z opisem pojęć, nad shellem (dolna nawigacja go nie zasłania).
Future<void> showTermInfo(BuildContext context, List<GlossaryTerm> terms) {
  final l10n = AppLocalizations.of(context);
  final theme = Theme.of(context);
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheet) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.gutter,
          0,
          AppSpacing.gutter,
          AppSpacing.l,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final term in terms) ...[
              Semantics(
                header: true,
                child: Text(
                  l10n.glossaryTermTitle(term),
                  style: theme.textTheme.titleLarge,
                ),
              ),
              const SizedBox(height: AppSpacing.s),
              Text(
                l10n.glossaryTermBody(term),
                style: theme.textTheme.bodyLarge,
              ),
              const SizedBox(height: AppSpacing.l),
            ],
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                icon: const Icon(Icons.menu_book_rounded),
                label: Text(l10n.glossaryAll),
                onPressed: () {
                  Navigator.of(sheet).pop();
                  unawaited(context.push(glossaryPath));
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
