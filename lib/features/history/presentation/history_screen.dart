import 'package:flutter/material.dart';

import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/widgets/empty_state.dart';

/// Historia sesji i progres. Implementacja w Etapie 5.
class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.navHistory)),
      body: EmptyState(
        icon: Icons.history_rounded,
        title: l10n.comingSoonTitle,
        message: l10n.historyPlaceholder,
      ),
    );
  }
}
