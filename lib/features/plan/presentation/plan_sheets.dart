import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/domain/exercise_groups.dart';
import '../../../core/domain/units.dart';
import '../../../core/l10n/formatters.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/superset_badge.dart';
import '../../exercises/domain/exercise.dart';
import '../../settings/data/settings_providers.dart';
import '../../templates/domain/set_plan.dart';
import '../../templates/domain/template.dart';

/// Akcje zaplanowanego treningu.
enum PlanEntryAction { moveTomorrow, moveTo, replace, skip }

/// Wybór szablonu (arkusz nad dolną nawigacją). Null po zamknięciu.
Future<Template?> pickTemplate(
  BuildContext context, {
  required List<Template> templates,
  required String Function(AppLocalizations l10n, Template template) preview,
}) {
  final l10n = AppLocalizations.of(context);
  if (templates.isEmpty) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(l10n.planNoTemplates)));
    return Future.value();
  }
  return showModalBottomSheet<Template>(
    context: context,
    useRootNavigator: true,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
            child: Text(
              l10n.planPickTemplate,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final template in templates)
                  ListTile(
                    title: Text(template.name),
                    subtitle: Text(preview(l10n, template)),
                    onTap: () => Navigator.of(context).pop(template),
                  ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

/// Podgląd szablonu: ćwiczenia z planem serii, „Rozpocznij” (gdy trening
/// jest na dziś) i „Edytuj szablon”.
Future<void> showTemplatePreview(
  BuildContext context, {
  required Template template,
  required Map<String, Exercise> catalog,
  VoidCallback? onStart,
}) => showModalBottomSheet<void>(
  context: context,
  useRootNavigator: true,
  showDragHandle: true,
  isScrollControlled: true,
  builder: (sheet) => _TemplatePreview(
    template: template,
    catalog: catalog,
    onStart: onStart == null
        ? null
        : () {
            Navigator.of(sheet).pop();
            onStart();
          },
    onEdit: () {
      Navigator.of(sheet).pop();
      unawaited(context.push(AppRoutes.templateEdit(template.id)));
    },
  ),
);

class _TemplatePreview extends ConsumerWidget {
  const _TemplatePreview({
    required this.template,
    required this.catalog,
    required this.onStart,
    required this.onEdit,
  });

  final Template template;
  final Map<String, Exercise> catalog;
  final VoidCallback? onStart;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toString();
    final unit =
        ref.watch(appSettingsProvider).value?.weightUnit ?? WeightUnit.kg;
    final exercises = template.exercises.sortedBy<num>((e) => e.position);
    final groups = groupLabels([for (final e in exercises) e.groupId]);
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.8,
        ),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.gutter,
            0,
            AppSpacing.gutter,
            AppSpacing.l,
          ),
          children: [
            Text(template.name, style: theme.textTheme.titleLarge),
            if (template.description case final description?) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                description,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.m),
            for (final (i, exercise) in exercises.indexed)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.m),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (groups[i] case final label?) ...[
                          SupersetBadge(label),
                          const SizedBox(width: AppSpacing.s),
                        ],
                        Expanded(
                          child: Text(
                            catalog[exercise.exerciseId]?.name ??
                                exercise.exerciseId,
                            style: theme.textTheme.titleSmall,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      _sets(exercise, unit, locale),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            Wrap(
              spacing: AppSpacing.s,
              runSpacing: AppSpacing.s,
              children: [
                if (onStart != null)
                  FilledButton.icon(
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: Text(l10n.planStart),
                    onPressed: onStart,
                  ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.edit_outlined),
                  label: Text(l10n.planEditTemplate),
                  onPressed: onEdit,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Serie, np. „3 × 8–12 · 80 kg”; kolejne jednakowe serie razem.
  static String _sets(TemplateExercise exercise, WeightUnit unit, String l) {
    final groups = <({String text, int count})>[];
    for (final set in resolveEffectiveSets(exercise)) {
      final text = [
        formatTarget(set.targetKind, set.targetMin, set.targetMax),
        if (set.targetWeightG case final w?) formatWeight(w, unit, l),
      ].where((p) => p.isNotEmpty).join(' · ');
      if (groups.lastOrNull?.text == text) {
        final last = groups.removeLast();
        groups.add((text: text, count: last.count + 1));
      } else {
        groups.add((text: text, count: 1));
      }
    }
    return [
      for (final g in groups)
        g.text.isEmpty ? '${g.count}×' : '${g.count} × ${g.text}',
    ].join(', ');
  }
}
