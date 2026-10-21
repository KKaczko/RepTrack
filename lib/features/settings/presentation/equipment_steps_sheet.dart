import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/formatters.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/theme/tokens.dart';
import '../../exercises/domain/exercise.dart';
import '../../exercises/presentation/exercise_labels.dart';
import '../data/settings_providers.dart';
import '../domain/app_settings.dart';

/// Arkusz „Kroki dla sprzętu” (ADR 0020): własny krok ciężaru dla hantli,
/// maszyn i innego sprzętu; „jak ogólny” usuwa wpis.
Future<void> showEquipmentStepsSheet(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => const _EquipmentStepsSheet(),
    );

class _EquipmentStepsSheet extends ConsumerWidget {
  const _EquipmentStepsSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final settings = ref.watch(appSettingsProvider).value;
    if (settings == null) return const SizedBox.shrink();
    final locale = Localizations.localeOf(context).toString();
    final unit = settings.weightUnit;
    String label(double step) =>
        '${formatDecimal(step, locale)} ${weightUnitLabel(unit)}';
    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.only(bottom: AppSpacing.l),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
            child: Text(
              l10n.settingsEquipmentSteps,
              style: theme.textTheme.titleLarge,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.gutter,
              AppSpacing.xs,
              AppSpacing.gutter,
              AppSpacing.s,
            ),
            child: Text(
              l10n.settingsEquipmentStepsHint(label(settings.weightStep)),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          for (final equipment in equipmentWithOwnStep)
            ListTile(
              title: Text(l10n.equipment(equipment)),
              trailing: Text(
                switch (settings.equipmentWeightSteps[equipment]) {
                  final step? => label(step),
                  null => l10n.settingsEquipmentStepGeneral,
                },
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onTap: () =>
                  unawaited(_choose(context, ref, settings, equipment, label)),
            ),
        ],
      ),
    );
  }

  Future<void> _choose(
    BuildContext context,
    WidgetRef ref,
    AppSettings settings,
    Equipment equipment,
    String Function(double) label,
  ) async {
    final l10n = AppLocalizations.of(context);
    final current = settings.equipmentWeightSteps[equipment];
    // Wynik: krok albo 0 dla „jak ogólny” (null = zamknięte bez wyboru).
    final picked = await showDialog<double>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(l10n.equipment(equipment)),
        children: [
          for (final (value, text) in [
            (0.0, l10n.settingsEquipmentStepGeneral),
            for (final step in equipmentStepOptions(settings.weightUnit))
              (step, label(step)),
          ])
            SimpleDialogOption(
              onPressed: () => Navigator.of(context).pop(value),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: AppSizes.minTouch),
                child: Row(
                  children: [
                    Expanded(child: Text(text)),
                    if (value == (current ?? 0))
                      const Icon(Icons.check_rounded),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
    if (picked == null) return;
    final steps = {...settings.equipmentWeightSteps};
    if (picked == 0) {
      steps.remove(equipment);
    } else {
      steps[equipment] = picked;
    }
    await ref
        .read(settingsRepositoryProvider)
        .save(settings.copyWith(equipmentWeightSteps: steps));
  }
}
