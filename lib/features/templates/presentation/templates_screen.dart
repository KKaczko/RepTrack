import 'package:flutter/material.dart';

import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/widgets/empty_state.dart';

/// Lista szablonów. Implementacja w Etapie 3.
class TemplatesScreen extends StatelessWidget {
  const TemplatesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.navTemplates)),
      body: EmptyState(
        icon: Icons.list_alt_rounded,
        title: l10n.comingSoonTitle,
        message: l10n.templatesPlaceholder,
      ),
    );
  }
}
