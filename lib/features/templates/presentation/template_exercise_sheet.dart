import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_providers.dart';
import '../../../core/domain/training.dart';
import '../../../core/domain/units.dart';
import '../../../core/l10n/formatters.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/clock_input_dialog.dart';
import '../../settings/data/settings_providers.dart';
import '../domain/set_plan.dart';
import '../domain/template.dart';
import 'template_labels.dart';

/// Wynik arkusza: zaktualizowane ćwiczenie albo usunięcie z szablonu.
final class TemplateExerciseSheetResult {
  const TemplateExerciseSheetResult.updated(TemplateExercise this.updated)
    : removed = false;

  const TemplateExerciseSheetResult.removed() : updated = null, removed = true;

  final TemplateExercise? updated;
  final bool removed;
}

Future<TemplateExerciseSheetResult?> showTemplateExerciseSheet(
  BuildContext context, {
  required TemplateExercise exercise,
  required String exerciseName,
}) => showModalBottomSheet<TemplateExerciseSheetResult>(
  context: context,
  useRootNavigator: true,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  builder: (context) =>
      TemplateExerciseSheet(exercise: exercise, exerciseName: exerciseName),
);

/// Konfiguracja ćwiczenia w szablonie (spec. 5.2): wspólny cel i ustawienia
/// dla wszystkich serii oraz nadpisania pojedynczych serii (ADR 0004).
class TemplateExerciseSheet extends ConsumerStatefulWidget {
  const TemplateExerciseSheet({
    required this.exercise,
    required this.exerciseName,
    super.key,
  });

  final TemplateExercise exercise;
  final String exerciseName;

  @override
  ConsumerState<TemplateExerciseSheet> createState() =>
      _TemplateExerciseSheetState();
}

class _TemplateExerciseSheetState extends ConsumerState<TemplateExerciseSheet> {
  late TemplateExercise _exercise = widget.exercise;

  void _update(TemplateExercise Function(TemplateExercise e) change) =>
      setState(() => _exercise = change(_exercise));

  /// Zmienia serię o indeksie [index] w kolejności `position`.
  void _updateSet(int index, TemplateSet Function(TemplateSet s) change) =>
      _update((e) {
        final sorted = e.sets.sortedBy<num>((s) => s.position);
        return e.copyWith(
          sets: [
            for (final (i, s) in sorted.indexed) i == index ? change(s) : s,
          ],
        );
      });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final unit =
        ref.watch(appSettingsProvider).value?.weightUnit ?? WeightUnit.kg;
    final locale = Localizations.localeOf(context).toString();
    final effective = resolveEffectiveSets(_exercise);
    final sortedSets = _exercise.sets.sortedBy<num>((s) => s.position);
    final commonInvalid = _invalid(_exercise.targetMin, _exercise.targetMax);

    return FractionallySizedBox(
      heightFactor: 0.92,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.gutter,
              0,
              AppSpacing.gutter,
              AppSpacing.s,
            ),
            child: Text(
              widget.exerciseName,
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.gutter),
              children: [
                Text(l10n.configTargetKind, style: theme.textTheme.titleSmall),
                const SizedBox(height: AppSpacing.s),
                SegmentedButton<TargetKind>(
                  segments: [
                    for (final kind in TargetKind.values)
                      ButtonSegment(
                        value: kind,
                        label: Text(l10n.targetKind(kind)),
                      ),
                  ],
                  selected: {_exercise.targetKind},
                  onSelectionChanged: (s) =>
                      _update((e) => e.copyWith(targetKind: s.single)),
                ),
                const SizedBox(height: AppSpacing.l),
                Text(
                  l10n.configCommonTarget,
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: AppSpacing.s),
                _RangeFields(
                  key: const ValueKey('common-target'),
                  min: _exercise.targetMin,
                  max: _exercise.targetMax,
                  invalid: commonInvalid,
                  onChanged: (min, max) => _update(
                    (e) => e.copyWith(targetMin: min, targetMax: max),
                  ),
                ),
                const SizedBox(height: AppSpacing.m),
                _WeightField(
                  key: const ValueKey('common-weight'),
                  label: l10n.configTargetWeight(weightUnitLabel(unit)),
                  grams: _exercise.targetWeightG,
                  unit: unit,
                  locale: locale,
                  onChanged: (g) =>
                      _update((e) => e.copyWith(targetWeightG: g)),
                ),
                const SizedBox(height: AppSpacing.m),
                _RestDropdown(
                  value: _exercise.restSeconds,
                  nullLabel: l10n.restDefault,
                  onChanged: (v) => _update((e) => e.copyWith(restSeconds: v)),
                ),
                const SizedBox(height: AppSpacing.m),
                DropdownButtonFormField<SetType>(
                  initialValue: _exercise.defaultSetType,
                  decoration: InputDecoration(labelText: l10n.configSetType),
                  items: [
                    for (final type in SetType.values)
                      DropdownMenuItem(
                        value: type,
                        child: Text(l10n.setType(type)),
                      ),
                  ],
                  onChanged: (v) =>
                      _update((e) => e.copyWith(defaultSetType: v!)),
                ),
                const SizedBox(height: AppSpacing.m),
                TextFormField(
                  initialValue: _exercise.note,
                  minLines: 1,
                  maxLines: 3,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(labelText: l10n.configNote),
                  onChanged: (v) => _update(
                    (e) => e.copyWith(note: v.trim().isEmpty ? null : v.trim()),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n.configSets,
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                    IconButton.outlined(
                      tooltip: l10n.configDecreaseSets,
                      onPressed: _exercise.setCount > 1
                          ? () => _update(
                              (e) => withSetCount(
                                e,
                                e.setCount - 1,
                                ref.read(idGeneratorProvider),
                              ),
                            )
                          : null,
                      icon: const Icon(Icons.remove_rounded),
                    ),
                    SizedBox(
                      width: 48,
                      child: Text(
                        '${_exercise.setCount}',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleLarge,
                      ),
                    ),
                    IconButton.outlined(
                      tooltip: l10n.configIncreaseSets,
                      onPressed: () => _update(
                        (e) => withSetCount(
                          e,
                          e.setCount + 1,
                          ref.read(idGeneratorProvider),
                        ),
                      ),
                      icon: const Icon(Icons.add_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  l10n.configSetOverridesHint,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.s),
                for (final (i, set) in sortedSets.indexed)
                  _SetEditor(
                    key: ValueKey(set.id),
                    index: i,
                    set: set,
                    effective: effective[i],
                    exercise: _exercise,
                    unit: unit,
                    locale: locale,
                    onChanged: (change) => _updateSet(i, change),
                  ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.gutter),
              child: Row(
                children: [
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: theme.colorScheme.error,
                    ),
                    icon: const Icon(Icons.delete_outline_rounded),
                    label: Text(l10n.configRemoveExercise),
                    onPressed: () =>
                        Navigator.of(context)
                            .pop(const TemplateExerciseSheetResult.removed()),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: () => Navigator.of(context)
                        .pop(TemplateExerciseSheetResult.updated(_exercise)),
                    child: Text(l10n.configDone),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

bool _invalid(int? min, int? max) => min != null && max != null && min > max;

/// Edytor jednej serii: wartość pusta albo „Wspólne” oznacza dziedziczenie.
class _SetEditor extends StatelessWidget {
  const _SetEditor({
    required this.index,
    required this.set,
    required this.effective,
    required this.exercise,
    required this.unit,
    required this.locale,
    required this.onChanged,
    super.key,
  });

  final int index;
  final TemplateSet set;
  final EffectiveSet effective;
  final TemplateExercise exercise;
  final WeightUnit unit;
  final String locale;
  final ValueChanged<TemplateSet Function(TemplateSet)> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final summary = l10n.effectiveSetSummary(effective, unit, locale);
    final inheritedWeight = exercise.targetWeightG == null
        ? null
        : formatWeightValue(exercise.targetWeightG!, unit, locale);

    return Card(
      // Arkusz ma kolor powierzchni; karty serii muszą się od niego odróżniać.
      color: context.appColors.surfaceRaised,
      margin: const EdgeInsets.only(bottom: AppSpacing.s),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        title: Text(l10n.configSetLabel(index + 1)),
        subtitle: Text(
          set.hasOverrides ? '$summary · ${l10n.configOverridden}' : summary,
          style: set.hasOverrides
              ? TextStyle(color: theme.colorScheme.primary)
              : null,
        ),
        childrenPadding: const EdgeInsets.fromLTRB(
          AppSpacing.l,
          0,
          AppSpacing.l,
          AppSpacing.l,
        ),
        children: [
          DropdownButtonFormField<SetType?>(
            // Klucz po wartości: po „Przywróć dziedziczenie” pole się odświeża.
            key: ValueKey('type-${set.setType}'),
            initialValue: set.setType,
            decoration: InputDecoration(labelText: l10n.configSetType),
            items: [
              DropdownMenuItem(
                child: Text(
                  '${l10n.configInherit} (${l10n.setType(exercise.defaultSetType)})',
                ),
              ),
              for (final type in SetType.values)
                DropdownMenuItem(value: type, child: Text(l10n.setType(type))),
            ],
            onChanged: (v) => onChanged((s) => s.copyWith(setType: v)),
          ),
          const SizedBox(height: AppSpacing.m),
          _RangeFields(
            min: set.targetMin,
            max: set.targetMax,
            fallbackMin: exercise.targetMin,
            fallbackMax: exercise.targetMax,
            invalid: _invalid(set.targetMin, set.targetMax),
            onChanged: (min, max) =>
                onChanged((s) => s.copyWith(targetMin: min, targetMax: max)),
          ),
          const SizedBox(height: AppSpacing.m),
          _WeightField(
            label: l10n.configTargetWeight(weightUnitLabel(unit)),
            grams: set.targetWeightG,
            hint: inheritedWeight,
            unit: unit,
            locale: locale,
            onChanged: (g) => onChanged((s) => s.copyWith(targetWeightG: g)),
          ),
          const SizedBox(height: AppSpacing.m),
          _RestDropdown(
            value: set.restSeconds,
            nullLabel:
                '${l10n.configInherit} (${l10n.rest(exercise.restSeconds)})',
            onChanged: (v) => onChanged((s) => s.copyWith(restSeconds: v)),
          ),
          const SizedBox(height: AppSpacing.s),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              icon: const Icon(Icons.restart_alt_rounded),
              label: Text(l10n.configRestoreInheritance),
              onPressed: set.hasOverrides
                  ? () => onChanged(
                      (s) => s.copyWith(
                        setType: null,
                        targetMin: null,
                        targetMax: null,
                        targetWeightG: null,
                        restSeconds: null,
                      ),
                    )
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}

/// Dwa pola liczbowe „od–do”.
///
/// Bez wartości zastępczych puste pole to null. Z wartościami zastępczymi
/// (nadpisanie serii) puste pole oznacza wartość wspólną, a dwa puste pola
/// usuwają nadpisanie celu.
class _RangeFields extends StatefulWidget {
  const _RangeFields({
    required this.min,
    required this.max,
    required this.invalid,
    required this.onChanged,
    this.fallbackMin,
    this.fallbackMax,
    super.key,
  });

  final int? min;
  final int? max;
  final int? fallbackMin;
  final int? fallbackMax;
  final bool invalid;
  final void Function(int? min, int? max) onChanged;

  @override
  State<_RangeFields> createState() => _RangeFieldsState();
}

class _RangeFieldsState extends State<_RangeFields> {
  late final _min = TextEditingController(text: _text(widget.min, true));
  late final _max = TextEditingController(text: _text(widget.max, false));

  /// Zmiana pochodzi z tych pól: nie nadpisujemy tekstu w trakcie pisania.
  bool _selfUpdate = false;

  /// Wartość równa zastępczej pokazujemy jako puste pole z podpowiedzią.
  String _text(int? value, bool isMin) {
    final fallback = isMin ? widget.fallbackMin : widget.fallbackMax;
    final hasFallbacks =
        widget.fallbackMin != null || widget.fallbackMax != null;
    if (value == null || (hasFallbacks && value == fallback)) return '';
    return '$value';
  }

  @override
  void didUpdateWidget(_RangeFields old) {
    super.didUpdateWidget(old);
    if (_selfUpdate) {
      _selfUpdate = false;
      return;
    }
    // Zmiana z zewnątrz, np. „Przywróć dziedziczenie”.
    _min.text = _text(widget.min, true);
    _max.text = _text(widget.max, false);
  }

  @override
  void dispose() {
    _min.dispose();
    _max.dispose();
    super.dispose();
  }

  void _emit() {
    final min = parseCount(_min.text);
    final max = parseCount(_max.text);
    _selfUpdate = true;
    if (min == null && max == null) {
      widget.onChanged(null, null);
    } else {
      widget.onChanged(min ?? widget.fallbackMin, max ?? widget.fallbackMax);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    InputDecoration decoration(String label, int? hint) => InputDecoration(
      labelText: label,
      hintText: hint?.toString(),
      errorText: widget.invalid ? '' : null,
      errorStyle: const TextStyle(height: 0),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _min,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: decoration(
                  l10n.configTargetMin,
                  widget.fallbackMin,
                ),
                onChanged: (_) => _emit(),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.s),
              child: Text('–'),
            ),
            Expanded(
              child: TextField(
                controller: _max,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: decoration(
                  l10n.configTargetMax,
                  widget.fallbackMax,
                ),
                onChanged: (_) => _emit(),
              ),
            ),
          ],
        ),
        if (widget.invalid)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: Text(
              l10n.templateInvalidTarget,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
      ],
    );
  }
}

/// Pole ciężaru w jednostce wyświetlania; puste pole to null.
class _WeightField extends StatefulWidget {
  const _WeightField({
    required this.label,
    required this.grams,
    required this.unit,
    required this.locale,
    required this.onChanged,
    this.hint,
    super.key,
  });

  final String label;
  final int? grams;
  final String? hint;
  final WeightUnit unit;
  final String locale;
  final ValueChanged<int?> onChanged;

  @override
  State<_WeightField> createState() => _WeightFieldState();
}

class _WeightFieldState extends State<_WeightField> {
  late final _controller = TextEditingController(text: _format(widget.grams));

  String _format(int? grams) =>
      grams == null ? '' : formatWeightValue(grams, widget.unit, widget.locale);

  @override
  void didUpdateWidget(_WeightField old) {
    super.didUpdateWidget(old);
    if (parseWeight(_controller.text, widget.unit) != widget.grams) {
      _controller.text = _format(widget.grams);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(
    controller: _controller,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
    decoration: InputDecoration(
      labelText: widget.label,
      hintText: widget.hint,
      suffixText: weightUnitLabel(widget.unit),
    ),
    onChanged: (text) => widget.onChanged(parseWeight(text, widget.unit)),
  );
}

/// Wartość pozycji „Inna…” w wyborze przerwy (otwiera wpis czasu).
const _customRest = -1;

class _RestDropdown extends StatefulWidget {
  const _RestDropdown({
    required this.value,
    required this.nullLabel,
    required this.onChanged,
  });

  final int? value;
  final String nullLabel;
  final ValueChanged<int?> onChanged;

  @override
  State<_RestDropdown> createState() => _RestDropdownState();
}

class _RestDropdownState extends State<_RestDropdown> {
  /// Odświeża pole po anulowaniu „Inna…”, żeby nie zostało na nim.
  int _reset = 0;

  Future<void> _custom() async {
    final seconds = await showRestInputDialog(context, initial: widget.value);
    if (!mounted) return;
    if (seconds == null) {
      setState(() => _reset++);
    } else {
      widget.onChanged(seconds);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final value = widget.value;
    final options = {...restOptions, value}.toList();
    return DropdownButtonFormField<int?>(
      key: ValueKey('rest-$value-$_reset'),
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: l10n.configRest),
      items: [
        for (final seconds in options)
          DropdownMenuItem(
            value: seconds,
            child: Text(
              seconds == null ? widget.nullLabel : formatClock(seconds),
            ),
          ),
        DropdownMenuItem(value: _customRest, child: Text(l10n.restCustom)),
      ],
      onChanged: (seconds) => seconds == _customRest
          ? unawaited(_custom())
          : widget.onChanged(seconds),
    );
  }
}
