import 'package:flutter/material.dart';

import '../../../core/domain/glossary.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/l10n/glossary_labels.dart';
import '../../../core/theme/tokens.dart';

/// Słowniczek: wszystkie pojęcia w grupach, z pełnymi opisami.
class GlossaryScreen extends StatelessWidget {
  const GlossaryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.glossaryTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.gutter,
          AppSpacing.s,
          AppSpacing.gutter,
          AppSpacing.xl,
        ),
        children: [
          Text(
            l10n.glossaryIntro,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          for (final group in GlossaryGroup.values) ...[
            Padding(
              padding: const EdgeInsets.only(
                top: AppSpacing.xl,
                bottom: AppSpacing.xs,
              ),
              child: Semantics(
                header: true,
                child: Text(
                  l10n.glossaryGroup(group),
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            ),
            for (final term in GlossaryTerm.values)
              if (term.group == group)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.m),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Semantics(
                        header: true,
                        child: Text(
                          l10n.glossaryTermTitle(term),
                          style: theme.textTheme.titleMedium,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        l10n.glossaryTermBody(term),
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
          ],
        ],
      ),
    );
  }
}
