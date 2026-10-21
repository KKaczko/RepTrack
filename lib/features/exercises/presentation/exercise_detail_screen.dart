import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/domain/glossary.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/term_info.dart';
import '../../workout/data/workout_providers.dart';
import '../data/exercise_providers.dart';
import '../domain/exercise.dart';
import '../domain/exercise_repository.dart';
import '../domain/substitutes.dart';
import 'exercise_labels.dart';
import 'exercise_providers.dart';
import 'exercises_screen.dart';

enum _Action { archive, unarchive, delete }

/// Dodatkowa zakładka ekranu ćwiczenia dostarczana przez inną funkcję
/// (historia, rekordy, wykresy). Łączy je router w `lib/app/`.
typedef ExerciseDetailTab = ({
  String Function(AppLocalizations l10n) label,
  Widget Function(String exerciseId) builder,
});

/// Szczegóły ćwiczenia: zakładka „Info” i zakładki z [extraTabs].
class ExerciseDetailScreen extends ConsumerWidget {
  const ExerciseDetailScreen({
    required this.exerciseId,
    this.extraTabs = const [],
    super.key,
  });

  final String exerciseId;
  final List<ExerciseDetailTab> extraTabs;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final exercise = ref.watch(exerciseByIdProvider(exerciseId));
    return switch (exercise) {
      AsyncData(value: final Exercise exercise) => _withTabs(
        l10n,
        exercise,
        appBar: AppBar(
          title: extraTabs.isEmpty
              ? null
              : Text(
                  exercise.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
          bottom: extraTabs.isEmpty
              ? null
              : TabBar(
                  // Przewijane: cztery zakładki nie mieszczą się na 360 dp
                  // przy większej czcionce.
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  tabs: [
                    Tab(text: l10n.exerciseTabInfo),
                    for (final tab in extraTabs) Tab(text: tab.label(l10n)),
                  ],
                ),
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

  Widget _withTabs(
    AppLocalizations l10n,
    Exercise exercise, {
    required PreferredSizeWidget appBar,
  }) {
    if (extraTabs.isEmpty) {
      return Scaffold(
        appBar: appBar,
        body: _ExerciseDetails(exercise: exercise),
      );
    }
    return DefaultTabController(
      length: 1 + extraTabs.length,
      child: Scaffold(
        appBar: appBar,
        body: TabBarView(
          children: [
            _ExerciseDetails(exercise: exercise),
            for (final tab in extraTabs) tab.builder(exercise.id),
          ],
        ),
      ),
    );
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
      key: const PageStorageKey('exercise-info'),
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
              info: true,
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
            _InfoRow(
              l10n.exerciseLoadMode,
              l10n.loadMode(exercise.loadMode),
              info: const [GlossaryTerm.loadMode],
            ),
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
        _SubstitutesSection(exercise: exercise),
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

/// Zamienniki ćwiczenia (ADR 0016): przypięte i do 5 propozycji; ★ przypina
/// albo odpina, dotknięcie otwiera zamiennik.
class _SubstitutesSection extends ConsumerWidget {
  const _SubstitutesSection({required this.exercise});

  final Exercise exercise;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final catalog = ref.watch(exerciseCatalogProvider).value ?? const [];
    final pins = ref.watch(substitutePinsProvider).value ?? const [];
    final history = ref.watch(completedSessionsProvider).value ?? const [];
    final repo = ref.read(substituteRepositoryProvider);
    final substitutes = suggestSubstitutes(
      exercise,
      catalog,
      pinned: pinnedFor(exercise.id, pins),
      used: {
        for (final session in history)
          for (final e in session.exercises) e.exerciseId,
      },
      limit: 5,
    );
    return _Section(
      title: l10n.exerciseSubstitutes,
      children: [
        Text(
          l10n.exerciseSubstitutesHint,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        if (substitutes.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.s),
            child: Text(l10n.substitutesEmpty),
          ),
        for (final substitute in substitutes)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(substitute.exercise.name),
            subtitle: Text(l10n.substituteSubtitle(substitute)),
            isThreeLine: true,
            trailing: IconButton(
              tooltip: substitute.pinned
                  ? l10n.substituteUnpin(substitute.exercise.name)
                  : l10n.substitutePin(substitute.exercise.name),
              icon: Icon(
                substitute.pinned
                    ? Icons.star_rounded
                    : Icons.star_outline_rounded,
                color: substitute.pinned ? theme.colorScheme.primary : null,
              ),
              onPressed: () => substitute.pinned
                  ? repo.unpin(exercise.id, substitute.exercise.id)
                  : repo.pin(exercise.id, substitute.exercise.id),
            ),
            onTap: () =>
                context.push(AppRoutes.exerciseDetail(substitute.exercise.id)),
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
    this.info = false,
  });

  final String label;
  final List<MuscleGroup> muscles;
  final bool primary;

  /// Ikonka ⓘ z opisem mięśni głównych i pomocniczych.
  final bool info;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = context.appColors;
    final labelStyle = theme.textTheme.labelLarge?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (info)
          TermTitle(
            label,
            terms: const [GlossaryTerm.muscleRoles],
            style: labelStyle,
          )
        else ...[
          Text(label, style: labelStyle),
          const SizedBox(height: AppSpacing.s),
        ],
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
  const _InfoRow(this.label, this.value, {this.info});

  final String label;
  final String value;

  /// Pojęcia z ikonką ⓘ na końcu wiersza.
  final List<GlossaryTerm>? info;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s),
      child: Row(
        crossAxisAlignment: info == null
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.center,
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
            // Ikonka w kolumnie wartości, żeby kolumny wierszy się zgadzały.
            child: switch (info) {
              final terms? => Row(
                children: [
                  Flexible(
                    child: Text(value, style: theme.textTheme.bodyMedium),
                  ),
                  TermInfoButton(terms),
                ],
              ),
              null => Text(value, style: theme.textTheme.bodyMedium),
            },
          ),
        ],
      ),
    );
  }
}
