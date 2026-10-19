import 'package:flutter/material.dart';

import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/theme/tokens.dart';

/// Licencje i źródła (spec. 5.1): pochodzenie danych biblioteki ćwiczeń,
/// font i pełna lista licencji pakietów.
class LicensesScreen extends StatelessWidget {
  const LicensesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    Widget section(String title, List<String> paragraphs) => Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.s),
          for (final paragraph in paragraphs)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.s),
              child: Text(paragraph, style: theme.textTheme.bodyMedium),
            ),
        ],
      ),
    );

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsLicenses)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.gutter),
        children: [
          section(l10n.licensesExercisesHeader, [
            l10n.licensesExercisesBody,
            l10n.licensesOwnBody,
            l10n.licensesImagesBody,
          ]),
          section(l10n.licensesFontHeader, [l10n.licensesFontBody]),
          OutlinedButton.icon(
            icon: const Icon(Icons.description_outlined),
            label: Text(l10n.licensesPackagesButton),
            onPressed: () => showLicensePage(
              context: context,
              applicationName: l10n.appTitle,
            ),
          ),
        ],
      ),
    );
  }
}
