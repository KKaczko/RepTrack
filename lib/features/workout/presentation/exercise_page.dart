import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/domain/training.dart';
import '../../../core/domain/units.dart';
import '../../../core/l10n/formatters.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../settings/data/settings_providers.dart';
import '../data/workout_providers.dart';
import '../domain/session_editing.dart';
import '../domain/set_hints.dart';
import '../domain/workout_session.dart';
import 'workout_labels.dart';

/// Podpowiedzi serii ćwiczenia: dopasowane poprzednie wykonanie i wartości
/// do zatwierdzenia. `loaded` jest false, dopóki trwa odczyt historii.
typedef ExerciseHints = ({
  Map<String, SessionSet> previous,
  Map<String, SetHint> hints,
  bool loaded,
});

/// Podpowiedzi dla wszystkich serii ćwiczenia sesji.
ExerciseHints watchExerciseHints(
  WidgetRef ref,
  String sessionId,
  SessionExercise exercise,
) {
  final history = ref.watch(
    previousSetsProvider((exercise.exerciseId, sessionId)),
  );
  final previousSets = history.value ?? const <SessionSet>[];
  return (
    previous: matchPreviousSets(exercise.sets, previousSets),
    hints: hintsForExercise(exercise, previousSets),
    loaded: history.hasValue,
  );
}

/// Strona jednego ćwiczenia: nagłówek z planem, tabela serii i dodawanie
/// serii. Wartości wpisuje się w strefie kciuka pod stroną.
class ExercisePage extends ConsumerWidget {
  const ExercisePage({
    required this.sessionId,
    required this.exercise,
    required this.index,
    required this.total,
    required this.selectedSetId,
    required this.onSelect,
    required this.onToggle,
    required this.onSetOptions,
    required this.onAddSet,
    required this.onPage,
    super.key,
  });

  final String sessionId;
  final SessionExercise exercise;
  final int index;
  final int total;
  final String? selectedSetId;
  final ValueChanged<SessionSet> onSelect;
  final ValueChanged<SessionSet> onToggle;
  final ValueChanged<SessionSet> onSetOptions;
  final VoidCallback onAddSet;
  final ValueChanged<int> onPage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = context.appColors;
    final unit =
        ref.watch(appSettingsProvider).value?.weightUnit ?? WeightUnit.kg;
    final locale = Localizations.localeOf(context).toString();
    final hints = watchExerciseHints(ref, sessionId, exercise);
    final sets = sortedSets(exercise);
    final secondary = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    return ListView(
      padding: const EdgeInsets.only(bottom: AppSpacing.l),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xs,
            0,
            AppSpacing.gutter,
            AppSpacing.s,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconButton(
                tooltip: l10n.workoutPreviousExercise,
                onPressed: index > 0 ? () => onPage(index - 1) : null,
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.s),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.workoutExerciseCounter(index + 1, total),
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      Text(
                        exercise.exerciseNameSnapshot,
                        style: theme.textTheme.titleLarge,
                      ),
                      Text(
                        l10n.sessionExercisePlan(exercise),
                        style: secondary,
                      ),
                      if (hints.loaded && hints.previous.isEmpty)
                        Text(l10n.workoutNoPrevious, style: secondary),
                      if (exercise.note case final note?)
                        Text(note, style: secondary),
                    ],
                  ),
                ),
              ),
              IconButton(
                tooltip: l10n.workoutNextExercise,
                onPressed: index < total - 1 ? () => onPage(index + 1) : null,
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
        ),
        _HeaderRow(
          values: l10n.valuesHeader(exercise.measurementSnapshot, unit),
          style: theme.textTheme.labelSmall?.copyWith(color: colors.textHint),
        ),
        for (final set in sets)
          _SetRow(
            key: ValueKey(set.id),
            set: set,
            exercise: exercise,
            previous: hints.previous[set.id],
            hint: hints.hints[set.id]!,
            selected: set.id == selectedSetId,
            unit: unit,
            locale: locale,
            onTap: () => onSelect(set),
            onToggle: () => onToggle(set),
            onLongPress: () => onSetOptions(set),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.gutter,
            AppSpacing.s,
            AppSpacing.gutter,
            0,
          ),
          child: Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: onAddSet,
              icon: const Icon(Icons.add_rounded),
              label: Text(l10n.workoutAddSet),
            ),
          ),
        ),
      ],
    );
  }
}

/// Szerokości kolumn tabeli serii (360 dp mieści wszystkie).
abstract final class _Columns {
  static const number = 40.0;
  static const plan = 60.0;
  static const previous = 76.0;
  static const check = AppSizes.minTouch;
}

class _HeaderRow extends StatelessWidget {
  const _HeaderRow({required this.values, required this.style});

  final String values;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ExcludeSemantics(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s),
        child: Row(
          children: [
            SizedBox(
              width: _Columns.number,
              child: Text('#', style: style, textAlign: TextAlign.center),
            ),
            SizedBox(
              width: _Columns.plan,
              child: Text(l10n.workoutColumnPlan, style: style),
            ),
            SizedBox(
              width: _Columns.previous,
              child: Text(l10n.workoutColumnPrevious, style: style),
            ),
            Expanded(
              child: Text(
                values,
                style: style,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: _Columns.check),
          ],
        ),
      ),
    );
  }
}

class _SetRow extends StatelessWidget {
  const _SetRow({
    required this.set,
    required this.exercise,
    required this.previous,
    required this.hint,
    required this.selected,
    required this.unit,
    required this.locale,
    required this.onTap,
    required this.onToggle,
    required this.onLongPress,
    super.key,
  });

  final SessionSet set;
  final SessionExercise exercise;
  final SessionSet? previous;
  final SetHint hint;
  final bool selected;
  final WeightUnit unit;
  final String locale;
  final VoidCallback onTap;
  final VoidCallback onToggle;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = context.appColors;
    final number = set.position + 1;
    final measurement = exercise.measurementSnapshot;
    final tag = l10n.setTypeTag(set.setType);
    final base = theme.textTheme.bodyLarge?.copyWith(
      fontFeatures: AppTheme.tabularFigures,
    );
    final muted = base?.copyWith(color: colors.textHint);
    final plan = formatTarget(
      set.targetKind ??
          (measurement.reps ? TargetKind.reps : TargetKind.duration),
      set.targetMin,
      set.targetMax,
    );
    final previousText = previous == null
        ? null
        : l10n.setValues(previous!, measurement, unit, locale);

    return Semantics(
      selected: selected,
      label: l10n.workoutSetSemantics(
        number,
        set.isCompleted ? l10n.workoutSetDone : l10n.workoutSetOpen,
      ),
      child: Material(
        color: selected ? colors.surfaceRaised : Colors.transparent,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          child: Container(
            constraints: const BoxConstraints(minHeight: AppSizes.minTouch),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s),
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(
                  width: 3,
                  color: selected ? colors.accentFill : Colors.transparent,
                ),
              ),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: _Columns.number,
                  child: Text(
                    tag.isEmpty ? '$number' : '$number$tag',
                    textAlign: TextAlign.center,
                    style: isWarmup(set) ? muted : base,
                  ),
                ),
                SizedBox(
                  width: _Columns.plan,
                  child: Text(plan.isEmpty ? '—' : plan, style: muted),
                ),
                SizedBox(
                  width: _Columns.previous,
                  child: Text(
                    previousText ?? '—',
                    style: muted,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Expanded(
                  child: _Values(
                    set: set,
                    hint: hint,
                    exercise: exercise,
                    unit: unit,
                    locale: locale,
                    base: base,
                    muted: muted,
                  ),
                ),
                SizedBox(
                  width: _Columns.check,
                  child: IconButton(
                    tooltip: set.isCompleted
                        ? l10n.workoutUndoSet(number)
                        : l10n.workoutConfirmSet(number),
                    onPressed: onToggle,
                    icon: Icon(
                      set.isCompleted
                          ? Icons.check_circle_rounded
                          : Icons.radio_button_unchecked_rounded,
                      color: set.isCompleted
                          ? colors.accentFill
                          : colors.textHint,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Wartości serii: wpisane albo zatwierdzone pełnym kontrastem, podpowiedzi
/// wyszarzone (spec. 5.3: podpowiedzi wyraźnie odróżnione).
class _Values extends StatelessWidget {
  const _Values({
    required this.set,
    required this.hint,
    required this.exercise,
    required this.unit,
    required this.locale,
    required this.base,
    required this.muted,
  });

  final SessionSet set;
  final SetHint hint;
  final SessionExercise exercise;
  final WeightUnit unit;
  final String locale;
  final TextStyle? base;
  final TextStyle? muted;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final fields = measuredFields(exercise.measurementSnapshot);
    final strong = base?.copyWith(fontWeight: FontWeight.w600);
    final spans = <TextSpan>[];
    for (final (i, field) in fields.indexed) {
      if (i > 0) {
        final pair = fields[i - 1] == SetField.weight && field == SetField.reps;
        spans.add(TextSpan(text: pair ? '×' : ' · ', style: muted));
      }
      final entered = setValue(set, field);
      final hinted = hintValue(hint, field);
      final value = entered ?? hinted?.value;
      spans.add(
        TextSpan(
          text: value == null
              ? '—'
              : l10n.fieldValue(field, value, unit, locale),
          style: entered != null ? strong : muted,
        ),
      );
    }
    return Text.rich(
      TextSpan(children: spans),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}
