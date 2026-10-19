import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/theme/tokens.dart';

/// Ustawienia. Motyw, jednostki, krok ciężaru, skala wysiłku i przerwy dochodzą
/// razem z funkcjami, które z nich korzystają (Etap 4).
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.gutter,
              AppSpacing.l,
              AppSpacing.gutter,
              AppSpacing.s,
            ),
            child: Text(
              l10n.settingsAbout,
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.gavel_rounded),
            title: Text(l10n.settingsLicenses),
            subtitle: Text(l10n.settingsLicensesSubtitle),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => context.push(AppRoutes.licenses),
          ),
        ],
      ),
    );
  }
}
