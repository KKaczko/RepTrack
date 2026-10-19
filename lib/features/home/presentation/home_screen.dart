import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/widgets/empty_state.dart';

/// Ekran Start. W Etapie 5: baner wznowienia, szybki start ostatniego
/// szablonu, ostatnia sesja i treningi w tym tygodniu.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appTitle),
        actions: [
          IconButton(
            tooltip: l10n.openSettings,
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push(AppRoutes.settings),
          ),
        ],
      ),
      body: EmptyState(
        icon: Icons.bolt_rounded,
        title: l10n.comingSoonTitle,
        message: l10n.homePlaceholder,
      ),
    );
  }
}
