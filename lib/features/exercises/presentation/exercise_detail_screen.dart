import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/empty_state.dart';
import '../data/exercise_providers.dart';
import '../domain/exercise.dart';
import '../domain/exercise_repository.dart';
import 'exercise_labels.dart';
import 'exercise_providers.dart';
import 'exercises_screen.dart';

enum _Action { archive, unarchive, delete }

/// Szczegóły ćwiczenia. Historia i rekordy dochodzą w Etapie 5.
class ExerciseDetailScreen extends ConsumerWidget {
  const ExerciseDetailScreen({required this.exerciseId, super.key});

  final String exerciseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final exercise = ref.watch(exerciseByIdProvider(exerciseId));
    return switch (exercise) {
      AsyncData(value: final Exercise exercise) => Scaffold(
        appBar: AppBar(
          actions: [
            IconButton(
              tooltip: l10n.exerciseEdit,
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => openExerciseForm(
                context,
                AppRoutes.exerciseEdit(exercise.id),
              ),
            ),
            PopupMenuButton<_Action>(
              tooltip: l10n.exerciseMoreActions,
              onSelected: (action) => _onAction(context, ref, exercise, action),
              itemBuilder: (context) => [
                if (exercise.isArchived)
                  PopupMenuItem(
                    value: _Action.unarchive,
                    child: Text(l10n.exerciseUnarchive),
                  )
                else
                  PopupMenuItem(
                    value: _Action.archive,
                    child: Text(l10n.exerciseArchive),
                  ),
                if (!exercise.isBuiltin)
                  PopupMenuItem(
                    value: _Action.delete,
                    child: Text(l10n.commonDelete),
                  ),
              ],
            ),
          ],
        ),
        body: _ExerciseDetails(exercise: exercise),
      ),
      AsyncData() => Scaffold(
        appBar: AppBar(),
        body: EmptyState(
          icon: Icons.help_outline_rounded,
          title: l10n.exerciseNotFound,
          message: '',
        ),
      ),
      AsyncError(:final error) => Scaffold(
        appBar: AppBar(),
        body: Center(child: Text('$error')),
      ),
      _ => Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      ),
    };
  }

  Future<void> _onAction(
    BuildContext context,
    WidgetRef ref,
    Exercise exercise,
    _Action action,
  ) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final repo = ref.read(exerciseRepositoryProvider);
    switch (action) {
      case _Action.archive || _Action.unarchive:
        final archive = action == _Action.archive;
        await repo.setArchived(exercise.id, archived: archive);
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              archive
                  ? l10n.exerciseArchivedSnack
                  : l10n.exerciseUnarchivedSnack,
            ),
          ),
        );
      case _Action.delete:
        if (await repo.isInUse(exercise.id)) {
          if (context.mounted) await _showInUse(context);
          return;
        }
        if (!context.mounted) return;
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(l10n.exerciseDeleteTitle),
            content: Text(l10n.exerciseDeleteMessage(exercise.name)),
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
        if (confirmed != true || !context.mounted) return;
        context.pop();
        try {
          await repo.delete(exercise.id);
          messenger.showSnackBar(
            SnackBar(content: Text(l10n.exerciseDeletedSnack)),
          );
        } on ExerciseInUseException {
          // Użyte między sprawdzeniem a usunięciem: nic nie usuwamy.
          messenger.showSnackBar(
            SnackBar(content: Text(l10n.exerciseInUseTitle)),
          );
        }
    }
  }

  Future<void> _showInUse(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.exerciseInUseTitle),
        content: Text(l10n.exerciseInUseMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.commonOk),
          ),
        ],
      ),
    );
  }
}

class _ExerciseDetails extends StatelessWidget {
  const _ExerciseDetails({required this.exercise});

  final Exercise exercise;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final cues = (exercise.instructions ?? '')
        .split('\n')
        .map((c) => c.trim())
        .where((c) => c.isNotEmpty)
        .toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.gutter,
        0,
        AppSpacing.gutter,
        AppSpacing.xxl,
      ),
      children: [
        Text(exercise.name, style: theme.textTheme.headlineSmall),
        if (exercise.aliases.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            '${l10n.exerciseAliases}: ${exercise.aliases.join(', ')}',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        if (exercise.isArchived) ...[
          const SizedBox(height: AppSpacing.s),
          Chip(
            avatar: const Icon(Icons.archive_outlined, size: 18),
            label: Text(l10n.exerciseArchivedBadge),
          ),
        ],
        const SizedBox(height: AppSpacing.l),
        _Section(
          children: [
            _MuscleRow(
              label: l10n.exercisePrimaryMuscles,
              muscles: exercise.primaryMuscles,
              primary: true,
            ),
            if (exercise.secondaryMuscles.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.m),
              _MuscleRow(
                label: l10n.exerciseSecondaryMuscles,
                muscles: exercise.secondaryMuscles,
                primary: false,
              ),
            ],
          ],
        ),
        _Section(
          title: l10n.exerciseDetails,
          children: [
            if (exercise.equipment != null)
              _InfoRow(
                l10n.exerciseEquipment,
                l10n.equipment(exercise.equipment!),
              ),
            _InfoRow(l10n.exerciseCategory, l10n.category(exercise.category)),
            if (exercise.mechanic != null)
              _InfoRow(
                l10n.exerciseMechanic,
                l10n.mechanic(exercise.mechanic!),
              ),
            if (exercise.force != null)
              _InfoRow(l10n.exerciseForce, l10n.force(exercise.force!)),
            _InfoRow(
              l10n.exerciseMeasurement,
              l10n.measurement(exercise.measurement),
            ),
            _InfoRow(l10n.exerciseLoadMode, l10n.loadMode(exercise.loadMode)),
            if (exercise.measurement.weight)
              _InfoRow(
                l10n.exerciseWeightSemantics,
                l10n.weightSemantics(exercise.weightSemantics),
              ),
            _InfoRow(
              l10n.exerciseUnilateral,
              exercise.isUnilateral ? l10n.commonYes : l10n.commonNo,
            ),
            if (exercise.isUnilateral)
              Text(
                l10n.exerciseUnilateralHint,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
        if (cues.isNotEmpty)
          _Section(
            title: l10n.exerciseTechnique,
            children: [
              for (final cue in cues)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.s),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Icon(
                          Icons.check_rounded,
                          size: 18,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.s),
                      Expanded(
                        child: Text(cue, style: theme.textTheme.bodyLarge),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        _Section(
          title: l10n.exerciseSource,
          children: [
            Text(
              exercise.isBuiltin
                  ? l10n.exerciseSourceBuiltin
                  : l10n.exerciseSourceUser,
              style: theme.textTheme.bodyLarge,
            ),
            if (exercise.licenseAuthor != null && exercise.isBuiltin)
              Text(l10n.exerciseAuthor(exercise.licenseAuthor!)),
            if (exercise.license != null)
              Text(l10n.exerciseLicense(exercise.license!)),
            if (exercise.userModified) ...[
              const SizedBox(height: AppSpacing.s),
              Text(
                l10n.exerciseUserModified,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.children, this.title});

  final String? title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.m),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.l),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (title != null) ...[
                Text(title!, style: theme.textTheme.titleMedium),
                const SizedBox(height: AppSpacing.m),
              ],
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}

class _MuscleRow extends StatelessWidget {
  const _MuscleRow({
    required this.label,
    required this.muscles,
    required this.primary,
  });

  final String label;
  final List<MuscleGroup> muscles;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = context.appColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.s),
        Wrap(
          spacing: AppSpacing.s,
          runSpacing: AppSpacing.s,
          children: [
            for (final muscle in muscles)
              Chip(
                label: Text(l10n.muscle(muscle)),
                backgroundColor: primary
                    ? colors.accentFill
                    : colors.surfaceRaised,
                labelStyle: TextStyle(
                  color: primary
                      ? colors.onAccentFill
                      : theme.colorScheme.onSurface,
                ),
                side: BorderSide.none,
              ),
          ],
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.m),
          Expanded(
            flex: 3,
            child: Text(value, style: theme.textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}
