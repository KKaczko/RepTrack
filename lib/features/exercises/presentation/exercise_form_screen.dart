import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/database/database_providers.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/theme/tokens.dart';
import '../data/exercise_providers.dart';
import '../domain/exercise.dart';
import 'exercise_labels.dart';

/// Dodawanie własnego ćwiczenia ([exerciseId] == null) albo edycja
/// istniejącego. Edycja ćwiczenia wbudowanego ustawia `userModified`, więc
/// aktualizacje biblioteki go nie nadpiszą (ADR 0005).
class ExerciseFormScreen extends ConsumerStatefulWidget {
  const ExerciseFormScreen({this.exerciseId, super.key});

  final String? exerciseId;

  @override
  ConsumerState<ExerciseFormScreen> createState() => _ExerciseFormScreenState();
}

class _ExerciseFormScreenState extends ConsumerState<ExerciseFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameKey = GlobalKey();
  final _name = TextEditingController();
  final _aliases = TextEditingController();
  final _instructions = TextEditingController();

  Exercise? _original;
  late Exercise _draft;
  bool _loaded = false;
  bool _measurementError = false;
  bool _saving = false;

  /// Wyjście dozwolone mimo zmian (po zapisie albo potwierdzeniu odrzucenia).
  bool _allowPop = false;

  @override
  void initState() {
    super.initState();
    _draft = const Exercise(id: '', name: '');
    unawaited(_load());
  }

  Future<void> _load() async {
    final id = widget.exerciseId;
    final existing = id == null
        ? null
        : await ref.read(exerciseRepositoryProvider).findById(id);
    if (!mounted) return;
    setState(() {
      _original = existing;
      _draft = existing ?? const Exercise(id: '', name: '');
      _name.text = _draft.name;
      _aliases.text = _draft.aliases.join(', ');
      _instructions.text = _draft.instructions ?? '';
      _loaded = true;
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _aliases.dispose();
    _instructions.dispose();
    super.dispose();
  }

  Exercise _build() {
    final aliases = <String>[];
    for (final raw in _aliases.text.split(',')) {
      final alias = raw.trim();
      if (alias.isNotEmpty && !aliases.contains(alias)) aliases.add(alias);
    }
    final instructions = _instructions.text
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .join('\n');
    return _draft.copyWith(
      name: _name.text.trim(),
      aliases: aliases,
      instructions: instructions.isEmpty ? null : instructions,
      secondaryMuscles: _draft.secondaryMuscles
          .where((m) => !_draft.primaryMuscles.contains(m))
          .toList(),
    );
  }

  bool get _isDirty {
    if (!_loaded) return false;
    final current = _build();
    final baseline = _original ?? const Exercise(id: '', name: '');
    return current != baseline;
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final validName = _formKey.currentState!.validate();
    final validMeasurement = _draft.measurement.isValid;
    setState(() => _measurementError = !validMeasurement);
    if (!validName) {
      final field = _nameKey.currentContext;
      if (field != null) await Scrollable.ensureVisible(field);
      return;
    }
    if (!validMeasurement) return;

    setState(() => _saving = true);
    final built = _build();
    final original = _original;
    final exercise = original == null
        ? built.copyWith(
            id: ref.read(idGeneratorProvider).newId(),
            source: ExerciseSource.user,
          )
        : built.copyWith(
            userModified: original.isBuiltin || original.userModified,
          );
    final messenger = ScaffoldMessenger.of(context);
    await ref.read(exerciseRepositoryProvider).save(exercise);
    if (!mounted) return;
    messenger.showSnackBar(SnackBar(content: Text(l10n.exerciseSavedSnack)));
    _leave();
  }

  /// Zamyka ekran po przebudowie z `canPop: true`, żeby PopScope nie
  /// zablokował wyjścia.
  void _leave() {
    setState(() => _allowPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.pop();
    });
  }

  Future<void> _confirmDiscard() async {
    final l10n = AppLocalizations.of(context);
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.exerciseFormDiscardTitle),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.commonDiscard),
          ),
        ],
      ),
    );
    if (discard == true && mounted) _leave();
  }

  void _update(Exercise Function(Exercise) change) =>
      setState(() => _draft = change(_draft));

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isNew = widget.exerciseId == null;

    return PopScope(
      canPop: _allowPop || !_isDirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_confirmDiscard());
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: l10n.commonClose,
            icon: const Icon(Icons.close_rounded),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          title: Text(
            isNew ? l10n.exerciseFormNewTitle : l10n.exerciseFormEditTitle,
          ),
        ),
        body: !_loaded
            ? const Center(child: CircularProgressIndicator())
            : Form(
                key: _formKey,
                // SingleChildScrollView zamiast ListView: wszystkie pola są
                // zawsze zbudowane, więc walidacja obejmuje też pola poza
                // ekranem.
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpacing.gutter),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_original?.isBuiltin ?? false) ...[
                        Text(
                          l10n.exerciseFormBuiltinNote,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.l),
                      ],
                      TextFormField(
                        key: _nameKey,
                        controller: _name,
                        autofocus: isNew,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: InputDecoration(
                          labelText: l10n.exerciseFormName,
                        ),
                        validator: (value) => (value ?? '').trim().isEmpty
                            ? l10n.exerciseFormNameRequired
                            : null,
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: AppSpacing.m),
                      TextFormField(
                        controller: _aliases,
                        decoration: InputDecoration(
                          labelText: l10n.exerciseAliases,
                          helperText: l10n.exerciseFormAliasesHelper,
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                      _Header(l10n.exercisePrimaryMuscles),
                      _ChipGroup<MuscleGroup>(
                        values: MuscleGroup.values,
                        selected: _draft.primaryMuscles.toSet(),
                        label: l10n.muscle,
                        onToggle: (m) => _update(
                          (d) => d.copyWith(
                            primaryMuscles: _toggled(d.primaryMuscles, m),
                          ),
                        ),
                      ),
                      _Header(l10n.exerciseSecondaryMuscles),
                      _ChipGroup<MuscleGroup>(
                        values: [
                          for (final m in MuscleGroup.values)
                            if (!_draft.primaryMuscles.contains(m)) m,
                        ],
                        selected: _draft.secondaryMuscles.toSet(),
                        label: l10n.muscle,
                        onToggle: (m) => _update(
                          (d) => d.copyWith(
                            secondaryMuscles: _toggled(d.secondaryMuscles, m),
                          ),
                        ),
                      ),
                      _Header(l10n.exerciseMeasurement),
                      Wrap(
                        spacing: AppSpacing.s,
                        runSpacing: AppSpacing.s,
                        children: [
                          _measureChip(
                            l10n.measureWeight,
                            _draft.measurement.weight,
                            (m, v) => m.copyWith(weight: v),
                          ),
                          _measureChip(
                            l10n.measureReps,
                            _draft.measurement.reps,
                            (m, v) => m.copyWith(reps: v),
                          ),
                          _measureChip(
                            l10n.measureDuration,
                            _draft.measurement.duration,
                            (m, v) => m.copyWith(duration: v),
                          ),
                          _measureChip(
                            l10n.measureDistance,
                            _draft.measurement.distance,
                            (m, v) => m.copyWith(distance: v),
                          ),
                        ],
                      ),
                      if (_measurementError)
                        Padding(
                          padding: const EdgeInsets.only(top: AppSpacing.s),
                          child: Text(
                            l10n.exerciseFormMeasurementRequired,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.error,
                            ),
                          ),
                        ),
                      const SizedBox(height: AppSpacing.l),
                      DropdownButtonFormField<Equipment?>(
                        initialValue: _draft.equipment,
                        decoration: InputDecoration(
                          labelText: l10n.exerciseEquipment,
                        ),
                        items: [
                          DropdownMenuItem(child: Text(l10n.commonNone)),
                          for (final e in Equipment.values)
                            DropdownMenuItem(
                              value: e,
                              child: Text(l10n.equipment(e)),
                            ),
                        ],
                        onChanged: (e) =>
                            _update((d) => d.copyWith(equipment: e)),
                      ),
                      const SizedBox(height: AppSpacing.m),
                      DropdownButtonFormField<ExerciseCategory>(
                        initialValue: _draft.category,
                        decoration: InputDecoration(
                          labelText: l10n.exerciseCategory,
                        ),
                        items: [
                          for (final c in ExerciseCategory.values)
                            DropdownMenuItem(
                              value: c,
                              child: Text(l10n.category(c)),
                            ),
                        ],
                        onChanged: (c) =>
                            _update((d) => d.copyWith(category: c!)),
                      ),
                      const SizedBox(height: AppSpacing.m),
                      DropdownButtonFormField<LoadMode>(
                        initialValue: _draft.loadMode,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: l10n.exerciseLoadMode,
                        ),
                        items: [
                          for (final m in LoadMode.values)
                            DropdownMenuItem(
                              value: m,
                              child: Text(l10n.loadMode(m)),
                            ),
                        ],
                        onChanged: (m) =>
                            _update((d) => d.copyWith(loadMode: m!)),
                      ),
                      if (_draft.measurement.weight) ...[
                        _Header(l10n.exerciseWeightSemantics),
                        SegmentedButton<WeightSemantics>(
                          segments: [
                            for (final s in WeightSemantics.values)
                              ButtonSegment(
                                value: s,
                                label: Text(l10n.weightSemantics(s)),
                              ),
                          ],
                          selected: {_draft.weightSemantics},
                          onSelectionChanged: (s) => _update(
                            (d) => d.copyWith(weightSemantics: s.single),
                          ),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.s),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(l10n.exerciseUnilateral),
                        subtitle: Text(l10n.exerciseUnilateralHint),
                        value: _draft.isUnilateral,
                        onChanged: (v) =>
                            _update((d) => d.copyWith(isUnilateral: v)),
                      ),
                      const SizedBox(height: AppSpacing.s),
                      TextFormField(
                        controller: _instructions,
                        minLines: 3,
                        maxLines: 8,
                        decoration: InputDecoration(
                          labelText: l10n.exerciseTechnique,
                          helperText: l10n.exerciseFormInstructionsHelper,
                          alignLabelWithHint: true,
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      SizedBox(
                        height: AppSizes.stepper,
                        child: FilledButton(
                          onPressed: _saving ? null : _save,
                          child: Text(l10n.commonSave),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _measureChip(
    String label,
    bool selected,
    Measurement Function(Measurement m, bool value) change,
  ) => FilterChip(
    label: Text(label),
    selected: selected,
    onSelected: (value) {
      _update((d) => d.copyWith(measurement: change(d.measurement, value)));
      if (_measurementError && _draft.measurement.isValid) {
        setState(() => _measurementError = false);
      }
    },
  );
}

List<T> _toggled<T>(List<T> list, T value) =>
    list.contains(value) ? (list.toList()..remove(value)) : [...list, value];

class _Header extends StatelessWidget {
  const _Header(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: AppSpacing.l, bottom: AppSpacing.s),
    child: Text(text, style: Theme.of(context).textTheme.titleMedium),
  );
}

class _ChipGroup<T> extends StatelessWidget {
  const _ChipGroup({
    required this.values,
    required this.selected,
    required this.label,
    required this.onToggle,
  });

  final List<T> values;
  final Set<T> selected;
  final String Function(T) label;
  final ValueChanged<T> onToggle;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: AppSpacing.s,
    runSpacing: AppSpacing.s,
    children: [
      for (final value in values)
        FilterChip(
          label: Text(label(value)),
          selected: selected.contains(value),
          onSelected: (_) => onToggle(value),
        ),
    ],
  );
}
