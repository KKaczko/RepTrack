import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/theme/tokens.dart';
import '../domain/exercise.dart';
import '../domain/exercise_filter.dart';
import 'exercise_labels.dart';
import 'exercise_providers.dart';

Future<void> showExerciseFilterSheet(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      // Nad shellem: snackbary i dolna nawigacja nie zasłaniają przycisków.
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => const ExerciseFilterSheet(),
    );

/// Arkusz filtrów katalogu. Zmiany działają od razu, a przycisk na dole
/// pokazuje liczbę wyników.
class ExerciseFilterSheet extends ConsumerWidget {
  const ExerciseFilterSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final filter = ref.watch(exerciseFilterProvider);
    final notifier = ref.read(exerciseFilterProvider.notifier);
    final count = ref.watch(filteredExercisesProvider).value?.length ?? 0;

    Set<T> toggle<T>(Set<T> set, T value) =>
        set.contains(value) ? ({...set}..remove(value)) : {...set, value};

    Widget section<T>(
      String title,
      List<T> values,
      Set<T> selected,
      String Function(T) label,
      ExerciseFilter Function(ExerciseFilter, Set<T>) apply,
    ) => Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.s),
          Wrap(
            spacing: AppSpacing.s,
            runSpacing: AppSpacing.s,
            children: [
              for (final value in values)
                FilterChip(
                  label: Text(label(value)),
                  selected: selected.contains(value),
                  onSelected: (_) =>
                      notifier.update((f) => apply(f, toggle(selected, value))),
                ),
            ],
          ),
        ],
      ),
    );

    return FractionallySizedBox(
      heightFactor: 0.9,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.exercisesFilters,
                    style: theme.textTheme.titleLarge,
                  ),
                ),
                TextButton(
                  onPressed: filter.activeCount == 0
                      ? null
                      : notifier.clearFilters,
                  child: Text(l10n.filterClear),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.gutter),
              children: [
                section(
                  l10n.filterMuscles,
                  MuscleGroup.values,
                  filter.muscles,
                  l10n.muscle,
                  (f, s) => f.copyWith(muscles: s),
                ),
                section(
                  l10n.filterEquipment,
                  Equipment.values,
                  filter.equipment,
                  l10n.equipment,
                  (f, s) => f.copyWith(equipment: s),
                ),
                section(
                  l10n.filterCategory,
                  ExerciseCategory.values,
                  filter.categories,
                  l10n.category,
                  (f, s) => f.copyWith(categories: s),
                ),
                Text(l10n.filterOrigin, style: theme.textTheme.titleMedium),
                const SizedBox(height: AppSpacing.s),
                SegmentedButton<ExerciseOrigin>(
                  segments: [
                    ButtonSegment(
                      value: ExerciseOrigin.all,
                      label: Text(l10n.filterOriginAll),
                    ),
                    ButtonSegment(
                      value: ExerciseOrigin.builtin,
                      label: Text(l10n.filterOriginBuiltin),
                    ),
                    ButtonSegment(
                      value: ExerciseOrigin.user,
                      label: Text(l10n.filterOriginUser),
                    ),
                  ],
                  selected: {filter.origin},
                  onSelectionChanged: (s) =>
                      notifier.update((f) => f.copyWith(origin: s.single)),
                ),
                const SizedBox(height: AppSpacing.s),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.filterArchived),
                  value: filter.archived,
                  onChanged: (v) =>
                      notifier.update((f) => f.copyWith(archived: v)),
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.gutter),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(l10n.filterShowResults(count)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
