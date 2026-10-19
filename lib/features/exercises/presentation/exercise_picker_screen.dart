import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/empty_state.dart';
import '../data/exercise_providers.dart';
import '../domain/exercise_filter.dart';
import 'exercise_labels.dart';

/// Wybór ćwiczeń dla szablonów i treningu. Zwraca listę identyfikatorów
/// w kolejności zaznaczania (`context.pop(List<String>)`).
class ExercisePickerScreen extends ConsumerStatefulWidget {
  const ExercisePickerScreen({super.key});

  @override
  ConsumerState<ExercisePickerScreen> createState() =>
      _ExercisePickerScreenState();
}

class _ExercisePickerScreenState extends ConsumerState<ExercisePickerScreen> {
  final _search = TextEditingController();
  final _selected = <String>[];
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _toggle(String id) => setState(
    () => _selected.contains(id) ? _selected.remove(id) : _selected.add(id),
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final catalog = ref.watch(exerciseCatalogProvider);
    final exercises = catalog.whenData(
      (all) => applyExerciseFilter(all, ExerciseFilter(query: _query)),
    );

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: l10n.commonClose,
          icon: const Icon(Icons.close_rounded),
          onPressed: () => context.pop(),
        ),
        title: Text(l10n.pickerTitle),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(AppSizes.minTouch + 16),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.gutter,
              0,
              AppSpacing.gutter,
              AppSpacing.s,
            ),
            child: TextField(
              controller: _search,
              autofocus: true,
              textInputAction: TextInputAction.search,
              onChanged: (value) => setState(() => _query = value),
              decoration: InputDecoration(
                hintText: l10n.exercisesSearchHint,
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: l10n.exercisesClearSearch,
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => setState(() {
                          _search.clear();
                          _query = '';
                        }),
                      ),
              ),
            ),
          ),
        ),
      ),
      // Przycisk w treści, nie w bottomNavigationBar: zostaje nad klawiaturą.
      body: Column(
        children: [
          Expanded(
            child: switch (exercises) {
              AsyncData(:final value) when value.isEmpty => Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  EmptyState(
                    icon: Icons.search_off_rounded,
                    title: l10n.exercisesEmptyTitle,
                    message: '',
                  ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.add_rounded),
                    label: Text(l10n.pickerCreateOwn),
                    onPressed: () => context.push(AppRoutes.exerciseNew),
                  ),
                ],
              ),
              AsyncData(:final value) => ListView.builder(
                itemCount: value.length,
                itemBuilder: (context, index) {
                  final exercise = value[index];
                  final selected = _selected.contains(exercise.id);
                  final summary = l10n.exerciseSummary(exercise);
                  return CheckboxListTile(
                    value: selected,
                    onChanged: (_) => _toggle(exercise.id),
                    title: Text(exercise.name),
                    subtitle: summary.isEmpty ? null : Text(summary),
                    controlAffinity: ListTileControlAffinity.trailing,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.gutter,
                    ),
                  );
                },
              ),
              AsyncError(:final error) => Center(child: Text('$error')),
              _ => const Center(child: CircularProgressIndicator()),
            },
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.gutter),
              child: SizedBox(
                height: AppSizes.stepper,
                child: FilledButton(
                  onPressed: _selected.isEmpty
                      ? null
                      : () => context.pop(List<String>.of(_selected)),
                  child: Text(l10n.pickerAdd(_selected.length)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
