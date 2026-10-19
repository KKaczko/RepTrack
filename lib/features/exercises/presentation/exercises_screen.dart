import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/empty_state.dart';
import '../domain/exercise.dart';
import 'exercise_filter_sheet.dart';
import 'exercise_labels.dart';
import 'exercise_providers.dart';

/// Katalog ćwiczeń: wyszukiwarka, filtry i lista.
class ExercisesScreen extends ConsumerStatefulWidget {
  const ExercisesScreen({super.key});

  @override
  ConsumerState<ExercisesScreen> createState() => _ExercisesScreenState();
}

class _ExercisesScreenState extends ConsumerState<ExercisesScreen> {
  late final TextEditingController _search = TextEditingController(
    text: ref.read(exerciseFilterProvider).query,
  );

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _setQuery(String value) =>
      ref.read(exerciseFilterProvider.notifier).setQuery(value);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final filterCount = ref.watch(
      exerciseFilterProvider.select((f) => f.activeCount),
    );
    final exercises = ref.watch(filteredExercisesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.navExercises),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(AppSizes.minTouch + 16),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.gutter,
              0,
              AppSpacing.s,
              AppSpacing.s,
            ),
            child: Row(
              children: [
                Expanded(
                  child: ValueListenableBuilder(
                    valueListenable: _search,
                    builder: (context, value, _) => TextField(
                      controller: _search,
                      onChanged: _setQuery,
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        hintText: l10n.exercisesSearchHint,
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: value.text.isEmpty
                            ? null
                            : IconButton(
                                tooltip: l10n.exercisesClearSearch,
                                icon: const Icon(Icons.close_rounded),
                                onPressed: () {
                                  _search.clear();
                                  _setQuery('');
                                },
                              ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                IconButton(
                  tooltip: l10n.exercisesFilters,
                  onPressed: () => showExerciseFilterSheet(context),
                  icon: Badge(
                    isLabelVisible: filterCount > 0,
                    label: Text('$filterCount'),
                    child: const Icon(Icons.tune_rounded),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => openExerciseForm(context, AppRoutes.exerciseNew),
        icon: const Icon(Icons.add_rounded),
        label: Text(l10n.exercisesAdd),
      ),
      body: switch (exercises) {
        AsyncData(:final value) when value.isEmpty => EmptyState(
          icon: Icons.search_off_rounded,
          title: l10n.exercisesEmptyTitle,
          message: l10n.exercisesEmptyMessage,
        ),
        AsyncData(:final value) => _ExerciseList(exercises: value),
        AsyncError(:final error) => Center(child: Text('$error')),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

/// Otwiera formularz ćwiczenia i po zapisie pokazuje komunikat na ekranie,
/// z którego go otwarto.
Future<void> openExerciseForm(BuildContext context, String location) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final saved = await context.push<bool>(location);
  if (saved ?? false) {
    messenger.showSnackBar(SnackBar(content: Text(l10n.exerciseSavedSnack)));
  }
}

class _ExerciseList extends StatelessWidget {
  const _ExerciseList({required this.exercises});

  final List<Exercise> exercises;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return ListView.builder(
      // Miejsce na przycisk „Dodaj ćwiczenie”.
      padding: const EdgeInsets.only(bottom: 96),
      itemCount: exercises.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.gutter,
              AppSpacing.xs,
              AppSpacing.gutter,
              AppSpacing.xs,
            ),
            child: Text(
              l10n.exercisesCount(exercises.length),
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          );
        }
        return ExerciseListTile(exercise: exercises[index - 1]);
      },
    );
  }
}

class ExerciseListTile extends StatelessWidget {
  const ExerciseListTile({required this.exercise, super.key});

  final Exercise exercise;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final summary = l10n.exerciseSummary(exercise);
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
      title: Text(exercise.name),
      subtitle: summary.isEmpty ? null : Text(summary),
      trailing: switch ((exercise.isArchived, exercise.isBuiltin)) {
        (true, _) => _Badge(label: l10n.exerciseArchivedBadge),
        (false, false) => _Badge(label: l10n.exerciseOwnBadge),
        _ => null,
      },
      onTap: () => context.push(AppRoutes.exerciseDetail(exercise.id)),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: context.appColors.surfaceRaised,
        borderRadius: BorderRadius.circular(AppRadius.s),
      ),
      child: Text(label, style: theme.textTheme.labelMedium),
    );
  }
}
