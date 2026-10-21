import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/formatters.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/theme/tokens.dart';
import '../../exercises/presentation/exercise_labels.dart';
import '../data/settings_providers.dart';
import '../domain/app_settings.dart';

/// „Gryf i talerze” (ADR 0020): waga gryfu dla sztangi i gryfu łamanego
/// oraz dostępne talerze dla kalkulatora w treningu. Zmiany zapisują się
/// od razu.
class PlatesScreen extends ConsumerWidget {
  const PlatesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final settings = ref.watch(appSettingsProvider).value;
    final locale = Localizations.localeOf(context).toString();
    if (settings == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final unit = settings.weightUnit;
    String label(double value) =>
        '${formatDecimal(value, locale)} ${weightUnitLabel(unit)}';
    Future<void> save(AppSettings next) =>
        ref.read(settingsRepositoryProvider).save(next);
    final plates = platesFor(settings);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.platesTitle)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.gutter),
        children: [
          Text(
            l10n.platesIntro,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          for (final equipment in equipmentWithPlates) ...[
            const SizedBox(height: AppSpacing.l),
            Text(
              l10n.platesBar(l10n.equipment(equipment)),
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.s),
            Wrap(
              spacing: AppSpacing.s,
              runSpacing: AppSpacing.xs,
              children: [
                for (final weight in barWeightOptions(unit))
                  ChoiceChip(
                    label: Text(label(weight)),
                    selected: barWeightFor(equipment, settings) == weight,
                    onSelected: (_) => save(
                      settings.copyWith(
                        barWeights: {...settings.barWeights, equipment: weight},
                      ),
                    ),
                  ),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.l),
          Text(l10n.platesAvailable, style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.s),
          Wrap(
            spacing: AppSpacing.s,
            runSpacing: AppSpacing.xs,
            children: [
              for (final plate in plateOptions(unit))
                FilterChip(
                  label: Text(label(plate)),
                  selected: plates.contains(plate),
                  onSelected: (on) {
                    final next = [
                      for (final p in plateOptions(unit))
                        if (p == plate ? on : plates.contains(p)) p,
                    ];
                    // Bez talerzy kalkulator nie ma sensu: zostaje ostatni.
                    if (next.isNotEmpty) {
                      unawaited(save(settings.copyWith(plates: next)));
                    }
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }
}
