import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/database/database_providers.dart';
import '../../../core/domain/units.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/theme/tokens.dart';
import '../../exercises/data/exercise_providers.dart';
import '../../exercises/domain/exercise.dart';
import '../../settings/data/settings_providers.dart';
import '../data/template_providers.dart';
import '../domain/template.dart';
import '../domain/template_editing.dart';
import 'template_exercise_sheet.dart';
import 'template_labels.dart';

/// Tworzenie ([templateId] == null) i edycja szablonu. Zmiany trafiają do
/// bazy po „Zapisz”; wyjście z niezapisanymi zmianami wymaga potwierdzenia.
class TemplateEditorScreen extends ConsumerStatefulWidget {
  const TemplateEditorScreen({this.templateId, super.key});

  final String? templateId;

  @override
  ConsumerState<TemplateEditorScreen> createState() =>
      _TemplateEditorScreenState();
}

class _TemplateEditorScreenState extends ConsumerState<TemplateEditorScreen> {
  final _name = TextEditingController();
  final _description = TextEditingController();

  late Template _baseline;
  late Template _draft;
  bool _loaded = false;
  bool _nameError = false;
  bool _saving = false;
  bool _allowPop = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final id = widget.templateId;
    final existing = id == null
        ? null
        : await ref.read(templateRepositoryProvider).findById(id);
    if (!mounted) return;
    final template =
        existing ??
        Template(id: ref.read(idGeneratorProvider).newId(), name: '');
    setState(() {
      _baseline = template;
      _draft = template;
      _name.text = template.name;
      _description.text = template.description ?? '';
      _loaded = true;
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  Template get _current {
    final description = _description.text.trim();
    return _draft.copyWith(
      name: _name.text.trim(),
      description: description.isEmpty ? null : description,
    );
  }

  bool get _isDirty => _loaded && _current != _baseline;

  Future<void> _addExercises() async {
    // Bez fokusu: po powrocie klawiatura nie wyskakuje ponownie.
    FocusScope.of(context).unfocus();
    final ids = await context.push<List<String>>(AppRoutes.exercisePicker);
    if (ids == null || ids.isEmpty || !mounted) return;
    final byId = ref.read(exercisesByIdProvider).value ?? const {};
    final exercises = [
      for (final id in ids)
        if (byId[id] != null) byId[id]!,
    ];
    setState(
      () => _draft = addExercises(
        _draft,
        exercises,
        ref.read(idGeneratorProvider),
      ),
    );
  }

  Future<void> _editExercise(TemplateExercise exercise, Exercise? info) async {
    FocusScope.of(context).unfocus();
    final result = await showTemplateExerciseSheet(
      context,
      exercise: exercise,
      exerciseName: info?.name ?? '…',
    );
    if (result == null || !mounted) return;
    setState(() {
      _draft = result.removed
          ? removeExercise(_draft, exercise.id)
          : replaceExercise(_draft, result.updated!);
    });
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final template = _current;
    final problems = validateTemplate(template);
    setState(() => _nameError = problems.contains(TemplateProblem.emptyName));
    if (problems.isNotEmpty) {
      final message = problems.contains(TemplateProblem.emptyName)
          ? l10n.templateNameRequired
          : l10n.templateInvalidTarget;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
      return;
    }
    setState(() => _saving = true);
    await ref.read(templateRepositoryProvider).save(template);
    if (!mounted) return;
    // Komunikat pokazuje lista szablonów, do której wracamy.
    _leave(saved: true);
  }

  /// Zamyka ekran po przebudowie z `canPop: true`, żeby PopScope nie
  /// zablokował wyjścia. Zwraca `true`, gdy szablon zapisano.
  void _leave({bool saved = false}) {
    setState(() => _allowPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.pop(saved);
    });
  }

  Future<void> _confirmDiscard() async {
    final l10n = AppLocalizations.of(context);
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.templateDiscardTitle),
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isNew = widget.templateId == null;

    return PopScope(
      // canPop liczone przy budowie bywa nieaktualne (np. tuż po wpisaniu
      // tekstu), więc decyzja zapada w chwili próby wyjścia.
      canPop: _allowPop,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_isDirty) {
          unawaited(_confirmDiscard());
        } else {
          _leave();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: l10n.commonClose,
            icon: const Icon(Icons.close_rounded),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          title: Text(
            isNew ? l10n.templateEditorNewTitle : l10n.templateEditorEditTitle,
          ),
          actions: [
            TextButton(
              onPressed: _loaded && !_saving ? _save : null,
              child: Text(l10n.commonSave),
            ),
          ],
        ),
        body: !_loaded
            ? const Center(child: CircularProgressIndicator())
            : _buildBody(context, l10n, theme),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    AppLocalizations l10n,
    ThemeData theme,
  ) {
    final byId = ref.watch(exercisesByIdProvider).value ?? const {};
    final unit =
        ref.watch(appSettingsProvider).value?.weightUnit ?? WeightUnit.kg;
    final locale = Localizations.localeOf(context).toString();
    final exercises = _draft.exercises;

    return ReorderableListView.builder(
      buildDefaultDragHandles: false,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.gutter,
        AppSpacing.m,
        AppSpacing.gutter,
        AppSpacing.xxl,
      ),
      header: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _name,
            autofocus: widget.templateId == null,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: l10n.templateName,
              hintText: l10n.templateNameHint,
              errorText: _nameError ? l10n.templateNameRequired : null,
            ),
            onChanged: (_) => setState(() => _nameError = false),
          ),
          const SizedBox(height: AppSpacing.m),
          TextField(
            controller: _description,
            textCapitalization: TextCapitalization.sentences,
            maxLines: 2,
            minLines: 1,
            decoration: InputDecoration(labelText: l10n.templateDescription),
            onChanged: (_) => setState(() {}),
          ),
          Padding(
            padding: const EdgeInsets.only(
              top: AppSpacing.xl,
              bottom: AppSpacing.s,
            ),
            child: Text(
              '${l10n.templateExercisesHeader} · '
              '${l10n.setCount(totalSets(_draft))}',
              style: theme.textTheme.titleMedium,
            ),
          ),
          if (exercises.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.m),
              child: Text(
                l10n.templateNoExercises,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
      footer: Padding(
        padding: const EdgeInsets.only(top: AppSpacing.s),
        child: SizedBox(
          height: AppSizes.stepper,
          child: OutlinedButton.icon(
            icon: const Icon(Icons.add_rounded),
            label: Text(l10n.templateAddExercises),
            onPressed: _addExercises,
          ),
        ),
      ),
      itemCount: exercises.length,
      onReorderItem: (from, to) =>
          setState(() => _draft = moveExercise(_draft, from, to)),
      itemBuilder: (context, index) {
        final item = exercises[index];
        final info = byId[item.exerciseId];
        final name = info == null
            ? '…'
            : info.isArchived
            ? l10n.exerciseArchivedSuffix(info.name)
            : info.name;
        return Padding(
          key: ValueKey(item.id),
          padding: const EdgeInsets.only(bottom: AppSpacing.s),
          child: Card(
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              contentPadding: const EdgeInsets.only(
                left: AppSpacing.l,
                right: AppSpacing.xs,
              ),
              title: Text(name),
              subtitle: Text(l10n.templateExerciseSummary(item, unit, locale)),
              onTap: () => _editExercise(item, info),
              trailing: ReorderableDragStartListener(
                index: index,
                child: Semantics(
                  label: l10n.templateDragHandle(name),
                  child: const SizedBox(
                    width: AppSizes.minTouch,
                    height: AppSizes.minTouch,
                    child: Icon(Icons.drag_handle_rounded),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
