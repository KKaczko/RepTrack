import 'package:flutter/material.dart';

import '../domain/exercise_groups.dart';
import '../l10n/generated/app_localizations.dart';

/// Plakietka ćwiczenia w superserii, np. „A1” (ADR 0018). Czytnik ekranu
/// słyszy „Superseria A, ćwiczenie 1”.
class SupersetBadge extends StatelessWidget {
  const SupersetBadge(this.label, {super.key});

  final GroupLabel label;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      container: true,
      label: l10n.supersetBadgeSemantics(label.letter, label.number),
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: scheme.primaryContainer,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          '${label.letter}${label.number}',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: scheme.onPrimaryContainer,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
