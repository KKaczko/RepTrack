import 'package:flutter/material.dart';

import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/widgets/empty_state.dart';

/// Ustawienia. Implementacja w kolejnych etapach.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: EmptyState(
        icon: Icons.tune_rounded,
        title: l10n.comingSoonTitle,
        message: l10n.settingsPlaceholder,
      ),
    );
  }
}
