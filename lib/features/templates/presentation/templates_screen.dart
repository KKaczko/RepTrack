import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/database/database_providers.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/active_workout_dialog.dart';
import '../../../core/widgets/empty_state.dart';
import '../../exercises/data/exercise_providers.dart';
import '../../workout/data/workout_providers.dart';
import '../data/template_providers.dart';
import '../domain/template.dart';
import '../domain/template_editing.dart';

enum _TemplateAction { duplicate, archive, unarchive, delete }

/// Lista szablonów z archiwum, duplikowaniem i usuwaniem.
class TemplatesScreen extends ConsumerStatefulWidget {
  const TemplatesScreen({super.key});

  @override
  ConsumerState<TemplatesScreen> createState() => _TemplatesScreenState();
}

class _TemplatesScreenState extends ConsumerState<TemplatesScreen> {
  bool _showArchived = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final templates = ref.watch(templatesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.navTemplates),
        actions: [
          IconButton(
            tooltip: _showArchived
                ? l10n.templatesShowActive
                : l10n.templatesShowArchived,
            icon: Icon(
              _showArchived
                  ? Icons.unarchive_outlined
                  : Icons.inventory_2_outlined,
            ),
            onPressed: () => setState(() => _showArchived = !_showArchived),
          ),
        ],
      ),
      floatingActionButton: _showArchived
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _openEditor(AppRoutes.templateNew),
              icon: const Icon(Icons.add_rounded),
              label: Text(l10n.templatesNew),
            ),
      body: switch (templates) {
        AsyncData(:final value) => _buildList(
          context,
          value.where((t) => t.isArchived == _showArchived).toList(),
        ),
        AsyncError(:final error) => Center(child: Text('$error')),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }

  Widget _buildList(BuildContext context, List<Template> templates) {
    final l10n = AppLocalizations.of(context);
    if (templates.isEmpty) {
      return _showArchived
          ? EmptyState(
              icon: Icons.inventory_2_outlined,
              title: l10n.templatesArchivedEmpty,
              message: '',
            )
          : EmptyState(
              icon: Icons.list_alt_rounded,
              title: l10n.templatesEmptyTitle,
              message: l10n.templatesEmptyMessage,
            );
    }
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 96),
      itemCount: templates.length,
      itemBuilder: (context, index) => _TemplateTile(
        template: templates[index],
        onAction: (action) => _onAction(templates[index], action),
        onOpen: () => _openEditor(AppRoutes.templateEdit(templates[index].id)),
        onStart: () => _start(templates[index]),
      ),
    );
  }

  Future<void> _openEditor(String location) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final saved = await context.push<bool>(location);
    if (saved ?? false) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.templateSavedSnack)));
    }
  }

  /// Start treningu z szablonu: jedno tapnięcie, potem ekran treningu.
  Future<void> _start(Template template) async {
    final started = await ref
        .read(workoutStarterProvider)
        .startFromTemplate(template);
    if (!mounted) return;
    if (started || await showActiveWorkoutDialog(context)) {
      if (mounted) await context.push(AppRoutes.workout);
    }
  }

  Future<void> _onAction(Template template, _TemplateAction action) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final repo = ref.read(templateRepositoryProvider);
    void snack(String text) =>
        messenger.showSnackBar(SnackBar(content: Text(text)));

    switch (action) {
      case _TemplateAction.duplicate:
        await repo.save(
          duplicateTemplate(
            template,
            ref.read(idGeneratorProvider),
            name: l10n.templateCopyName(template.name),
          ),
        );
        snack(l10n.templateDuplicatedSnack);
      case _TemplateAction.archive:
        await repo.setArchived(template.id, archived: true);
        snack(l10n.templateArchivedSnack);
      case _TemplateAction.unarchive:
        await repo.setArchived(template.id, archived: false);
        snack(l10n.templateUnarchivedSnack);
      case _TemplateAction.delete:
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(l10n.templateDeleteTitle),
            content: Text(l10n.templateDeleteMessage(template.name)),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(l10n.commonCancel),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(l10n.commonDelete),
              ),
            ],
          ),
        );
        if (confirmed != true) return;
        await repo.delete(template.id);
        snack(l10n.templateDeletedSnack);
    }
  }
}

class _TemplateTile extends ConsumerWidget {
  const _TemplateTile({
    required this.template,
    required this.onAction,
    required this.onOpen,
    required this.onStart,
  });

  final Template template;
  final ValueChanged<_TemplateAction> onAction;
  final VoidCallback onOpen;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final names = ref.watch(exercisesByIdProvider).value ?? const {};
    final exerciseNames = [
      for (final e in template.exercises) names[e.exerciseId]?.name ?? '…',
    ];
    final summary = l10n.templateSummary(
      l10n.exercisesCount(template.exercises.length),
      l10n.setCount(totalSets(template)),
    );

    return ListTile(
      contentPadding: const EdgeInsets.only(
        left: AppSpacing.gutter,
        right: AppSpacing.xs,
      ),
      title: Text(template.name),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(summary),
          if (exerciseNames.isNotEmpty)
            Text(
              exerciseNames.join(', '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
      onTap: onOpen,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!template.isArchived && template.exercises.isNotEmpty)
            IconButton.filled(
              tooltip: l10n.workoutStart,
              onPressed: onStart,
              style: IconButton.styleFrom(
                backgroundColor: context.appColors.accentFill,
                foregroundColor: context.appColors.onAccentFill,
              ),
              icon: Icon(
                Icons.play_arrow_rounded,
                color: context.appColors.onAccentFill,
              ),
            ),
          _menu(l10n),
        ],
      ),
    );
  }

  Widget _menu(AppLocalizations l10n) => PopupMenuButton<_TemplateAction>(
    tooltip: l10n.templateActions,
    onSelected: onAction,
    itemBuilder: (context) => [
      if (!template.isArchived)
        PopupMenuItem(
          value: _TemplateAction.duplicate,
          child: Text(l10n.templateDuplicate),
        ),
      if (template.isArchived)
        PopupMenuItem(
          value: _TemplateAction.unarchive,
          child: Text(l10n.templateUnarchive),
        )
      else
        PopupMenuItem(
          value: _TemplateAction.archive,
          child: Text(l10n.templateArchive),
        ),
      PopupMenuItem(
        value: _TemplateAction.delete,
        child: Text(l10n.commonDelete),
      ),
    ],
  );
}
