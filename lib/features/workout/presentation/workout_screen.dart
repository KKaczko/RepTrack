import 'dart:async';
import 'dart:math';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/database/database_providers.dart';
import '../../../core/domain/units.dart';
import '../../../core/l10n/formatters.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/platform/device_services.dart';
import '../../../core/platform/rest_notifications.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/ticker_builder.dart';
import '../../exercises/data/exercise_providers.dart';
import '../../exercises/domain/exercise.dart';
import '../../settings/data/settings_providers.dart';
import '../../settings/domain/app_settings.dart';
import '../data/workout_providers.dart';
import '../domain/session_editing.dart';
import '../domain/set_hints.dart';
import '../domain/workout_session.dart';
import 'exercise_page.dart';
import 'substitute_sheet.dart';
import 'thumb_zone.dart';
import 'value_sheets.dart';
import 'workout_controller.dart';
import 'workout_labels.dart';

/// Po zatwierdzeniu serii kolejne tapnięcie w tym czasie jest ignorowane,
/// żeby przypadkowe podwójne tapnięcie nie zatwierdziło dwóch serii.
const _confirmCooldown = Duration(milliseconds: 350);

enum _MenuAction { addExercises, replace, remove, reorder, finish, discard }

/// Aktywny trening (spec. 5.3, docs/ux.md): strona na ćwiczenie, tabela
/// serii z podpowiedziami i strefa kciuka z głównym przyciskiem.
class WorkoutScreen extends ConsumerStatefulWidget {
  const WorkoutScreen({super.key});

  @override
  ConsumerState<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends ConsumerState<WorkoutScreen> {
  final _messenger = GlobalKey<ScaffoldMessengerState>();
  PageController? _pages;

  /// Ćwiczenie sesji na widocznej stronie; przetrwa zmianę kolejności.
  String? _currentId;
  int _lastIndex = 0;
  List<SessionExercise> _exercises = const [];

  /// Seria wybrana tapnięciem w wiersz (id ćwiczenia → id serii). Bez wyboru
  /// strefa kciuka działa na pierwszą niezatwierdzoną serię.
  final _selected = <String, String>{};
  Timer? _cooldown;
  late final ScreenAwake _awake;
  bool _leaving = false;
  bool _leavePending = false;

  WorkoutController get _controller => ref.read(workoutControllerProvider);

  @override
  void initState() {
    super.initState();
    _awake = ref.read(screenAwakeProvider);
    ref.listenManual(
      appSettingsProvider,
      (_, next) => unawaited(
        _awake.setEnabled(
          enabled: next.value?.keepScreenOn ?? const AppSettings().keepScreenOn,
        ),
      ),
      fireImmediately: true,
    );
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => unawaited(_promptExactAlarms()),
    );
  }

  /// Jednorazowa prośba o dokładne alarmy końca przerwy (ADR 0009). Bez
  /// zgody Android może opóźnić powiadomienie nawet o minutę.
  Future<void> _promptExactAlarms() async {
    final repo = ref.read(settingsRepositoryProvider);
    final notifications = ref.read(restNotificationsProvider);
    final settings = await repo.load();
    if (settings.exactAlarmPrompted) return;
    bool allowed;
    try {
      allowed = await notifications.exactAlarmsAllowed();
    } on Object {
      allowed = true;
    }
    if (allowed || !mounted) return;
    await repo.save(settings.copyWith(exactAlarmPrompted: true));
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    final allow = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.alarm_rounded),
        title: Text(l10n.exactAlarmDialogTitle),
        content: Text(l10n.exactAlarmDialogMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.exactAlarmDialogLater),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.exactAlarmDialogAllow),
          ),
        ],
      ),
    );
    if (allow ?? false) await notifications.requestExactAlarms();
  }

  @override
  void dispose() {
    unawaited(_awake.setEnabled(enabled: false));
    _cooldown?.cancel();
    _pages?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final active = ref.watch(activeSessionProvider);
    final session = active.value;
    if (session == null) {
      if (active.hasValue) _leaveWhenGone();
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final settings =
        ref.watch(appSettingsProvider).value ?? const AppSettings();
    final exercises = _exercises = sortedExercises(session);
    final index = _resolveIndex(exercises);

    return ScaffoldMessenger(
      key: _messenger,
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: l10n.workoutMinimize,
            icon: const Icon(Icons.keyboard_arrow_down_rounded),
            onPressed: () => context.pop(),
          ),
          titleSpacing: 0,
          title: Text(
            session.title ?? l10n.workoutTitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          actions: [
            _Elapsed(startedAt: session.startedAt),
            PopupMenuButton<_MenuAction>(
              tooltip: l10n.workoutMenu,
              onSelected: (action) => _onMenu(action, session),
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: _MenuAction.addExercises,
                  child: Text(l10n.workoutAddExercises),
                ),
                if (exercises.isNotEmpty) ...[
                  PopupMenuItem(
                    value: _MenuAction.replace,
                    child: Text(l10n.workoutReplaceExercise),
                  ),
                  PopupMenuItem(
                    value: _MenuAction.remove,
                    child: Text(l10n.workoutRemoveExercise),
                  ),
                ],
                if (exercises.length > 1)
                  PopupMenuItem(
                    value: _MenuAction.reorder,
                    child: Text(l10n.workoutReorder),
                  ),
                const PopupMenuDivider(),
                PopupMenuItem(
                  value: _MenuAction.finish,
                  child: Text(l10n.workoutFinish),
                ),
                PopupMenuItem(
                  value: _MenuAction.discard,
                  child: Text(l10n.workoutDiscard),
                ),
              ],
            ),
          ],
        ),
        body: exercises.isEmpty
            ? _EmptyWorkout(onAdd: _addExercises)
            : Column(
                children: [
                  Expanded(
                    child: PageView.builder(
                      controller: _pages,
                      itemCount: exercises.length,
                      onPageChanged: (i) =>
                          setState(() => _currentId = _exercises[i].id),
                      itemBuilder: (context, i) =>
                          _buildPage(session, exercises, i),
                    ),
                  ),
                  _buildThumbZone(session, exercises[index], settings),
                ],
              ),
      ),
    );
  }

  /// Indeks widocznego ćwiczenia. Przy pierwszym wejściu to pierwsze
  /// ćwiczenie z niezatwierdzoną serią; po zmianie kolejności strona
  /// podąża za ćwiczeniem.
  int _resolveIndex(List<SessionExercise> exercises) {
    if (exercises.isEmpty) return 0;
    var index = exercises.indexWhere((e) => e.id == _currentId);
    if (index < 0) {
      index = _currentId == null
          ? max(0, exercises.indexWhere((e) => nextOpenSet(e) != null))
          : min(_lastIndex, exercises.length - 1);
      _currentId = exercises[index].id;
    }
    _lastIndex = index;
    final pages = _pages ??= PageController(initialPage: index);
    if (pages.hasClients && pages.page?.round() != index) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (pages.hasClients && pages.page?.round() != _lastIndex) {
          pages.jumpToPage(_lastIndex);
        }
      });
    }
    return index;
  }

  Widget _buildPage(
    WorkoutSession session,
    List<SessionExercise> exercises,
    int index,
  ) {
    final exercise = exercises[index];
    return ExercisePage(
      key: ValueKey(exercise.id),
      sessionId: session.id,
      exercise: exercise,
      index: index,
      total: exercises.length,
      selectedSetId: _selectedSetId(exercise),
      onSelect: (set) => setState(() => _selected[exercise.id] = set.id),
      onToggle: (set) => set.isCompleted
          ? unawaited(_controller.uncomplete(exercise.id, set.id))
          : unawaited(_confirm(exercise, set)),
      onSetOptions: (set) => _setOptions(exercise, set),
      onAddSet: () => unawaited(_controller.addSet(exercise.id)),
      onPage: _goToIndex,
      onSubstitute: () => unawaited(_substitute(exercise)),
    );
  }

  Widget _buildThumbZone(
    WorkoutSession session,
    SessionExercise exercise,
    AppSettings settings,
  ) {
    final hints = watchExerciseHints(ref, session.id, exercise);
    final setId = _selectedSetId(exercise);
    final set = exercise.sets.firstWhereOrNull((s) => s.id == setId);
    final hint = set == null ? null : hints.hints[set.id];
    final scale = settings.effortScale;
    return ThumbZone(
      exercise: exercise,
      set: set,
      hint: hint,
      unit: settings.weightUnit,
      effortScale: scale,
      restEndsAt: session.restEndsAt,
      primary: _primaryAction(session, exercise, set, loaded: hints.loaded),
      onStep: (field, direction) {
        if (set != null && hint != null) {
          _step(exercise, set, hint, field, direction, settings);
        }
      },
      onEditValue: (field) {
        if (set != null && hint != null) {
          final current = setValue(set, field) ?? hintValue(hint, field)?.value;
          unawaited(_editValue(exercise, set, field, current, settings));
        }
      },
      onEffort: (tenths) {
        if (set != null && scale != null) {
          unawaited(_controller.setEffort(exercise.id, set.id, scale, tenths));
        }
      },
      onRestAdjust: (delta) => unawaited(
        _controller.adjustRest(delta, currentExerciseId: exercise.id),
      ),
      onRestSkip: () => unawaited(_controller.skipRest()),
    );
  }

  PrimaryAction _primaryAction(
    WorkoutSession session,
    SessionExercise exercise,
    SessionSet? set, {
    required bool loaded,
  }) {
    final l10n = AppLocalizations.of(context);
    if (set != null && !set.isCompleted) {
      return PrimaryAction(
        label: l10n.workoutConfirmSet(set.position + 1),
        icon: Icons.check_rounded,
        onPressed: loaded ? () => unawaited(_confirm(exercise, set)) : null,
      );
    }
    if (set != null) {
      return PrimaryAction(
        label: l10n.workoutUndoSet(set.position + 1),
        icon: Icons.undo_rounded,
        emphasized: false,
        onPressed: () => unawaited(_controller.uncomplete(exercise.id, set.id)),
      );
    }
    final next = nextExerciseToDo(session, exercise.id);
    if (next != null && next.id != exercise.id) {
      return PrimaryAction(
        label: l10n.workoutNextExercise,
        icon: Icons.arrow_forward_rounded,
        onPressed: () => _goToIndex(_exercises.indexOf(next)),
      );
    }
    return PrimaryAction(
      label: l10n.workoutFinish,
      icon: Icons.flag_rounded,
      onPressed: _openFinish,
    );
  }

  String? _selectedSetId(SessionExercise exercise) {
    final chosen = _selected[exercise.id];
    if (chosen != null && exercise.sets.any((s) => s.id == chosen)) {
      return chosen;
    }
    return nextOpenSet(exercise)?.id;
  }

  void _goToIndex(int index) {
    if (index < 0 || index >= _exercises.length) return;
    setState(() => _currentId = _exercises[index].id);
    unawaited(
      _pages?.animateToPage(
        index,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
      ),
    );
  }

  Future<void> _confirm(SessionExercise exercise, SessionSet set) async {
    if (_cooldown?.isActive ?? false) return;
    _cooldown = Timer(_confirmCooldown, () {});
    final missing = await _controller.confirm(exercise.id, set.id);
    if (!mounted) return;
    if (missing.isNotEmpty) {
      // Brak wartości i podpowiedzi (np. pierwsze wykonanie bez planu):
      // od razu wpis brakującego pola zamiast komunikatu.
      _cooldown?.cancel();
      await _editValue(
        exercise,
        set,
        missing.first,
        null,
        ref.read(appSettingsProvider).value ?? const AppSettings(),
        missing: true,
      );
      return;
    }
    setState(() => _selected.remove(exercise.id));
    unawaited(HapticFeedback.lightImpact());
  }

  void _step(
    SessionExercise exercise,
    SessionSet set,
    SetHint hint,
    SetField field,
    int direction,
    AppSettings settings,
  ) {
    final current = setValue(set, field) ?? hintValue(hint, field)?.value ?? 0;
    final unit = settings.weightUnit;
    final next = switch (field) {
      SetField.weight => displayToGrams(
        stepValue(
          gramsToDisplay(current, unit),
          settings.weightStep,
          direction,
        ),
        unit,
      ),
      SetField.reps => max(0, current + direction * repsStep),
      SetField.duration => max(0, current + direction * durationStepSeconds),
      SetField.distance => max(0, current + direction * distanceStepMeters),
    };
    unawaited(_controller.setValue(exercise.id, set.id, field, next));
  }

  /// Wpis wartości pola z arkusza. [missing] oznacza, że pole trzeba
  /// uzupełnić przed zatwierdzeniem serii.
  Future<void> _editValue(
    SessionExercise exercise,
    SessionSet set,
    SetField field,
    int? current,
    AppSettings settings, {
    bool missing = false,
  }) async {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toString();
    final unit = settings.weightUnit;
    final title = missing
        ? l10n.workoutCompleteMissing(l10n.fieldLabel(field))
        : l10n.fieldLabel(field);
    final int? value;
    switch (field) {
      case SetField.reps:
        value = await showRepsPicker(context, current: current, title: title);
      case SetField.weight:
        final text = await showValueInput(
          context,
          title: title,
          initial: current == null
              ? ''
              : formatWeightValue(current, unit, locale),
          decimal: true,
          suffix: weightUnitLabel(unit),
        );
        value = text == null ? null : parseWeight(text, unit);
      case SetField.duration || SetField.distance:
        final text = await showValueInput(
          context,
          title: title,
          initial: current?.toString() ?? '',
          decimal: false,
          suffix: field == SetField.duration
              ? l10n.workoutUnitSeconds
              : l10n.workoutUnitMeters,
        );
        value = text == null ? null : parseCount(text);
    }
    if (value == null) return;
    await _controller.setValue(exercise.id, set.id, field, value);
  }

  Future<void> _setOptions(SessionExercise exercise, SessionSet set) async {
    final l10n = AppLocalizations.of(context);
    final remove = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.gutter,
              ),
              child: Text(
                '${exercise.exerciseNameSnapshot} · '
                '${l10n.configSetLabel(set.position + 1)}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: AppSpacing.s),
            ListTile(
              leading: Icon(
                Icons.delete_outline_rounded,
                color: Theme.of(context).colorScheme.error,
              ),
              title: Text(l10n.workoutRemoveSet),
              onTap: () => Navigator.of(context).pop(true),
            ),
          ],
        ),
      ),
    );
    if (remove ?? false) await _controller.removeSet(exercise.id, set.id);
  }

  Future<void> _onMenu(_MenuAction action, WorkoutSession session) async {
    final current = _exercises.firstWhereOrNull((e) => e.id == _currentId);
    switch (action) {
      case _MenuAction.addExercises:
        await _addExercises();
      case _MenuAction.replace:
        if (current != null) await _replace(current);
      case _MenuAction.remove:
        if (current != null) await _remove(current);
      case _MenuAction.reorder:
        await showModalBottomSheet<void>(
          context: context,
          showDragHandle: true,
          isScrollControlled: true,
          builder: (context) => _ReorderSheet(exercises: _exercises),
        );
      case _MenuAction.finish:
        _openFinish();
      case _MenuAction.discard:
        await _discard();
    }
  }

  Future<List<String>> _pickExercises({bool single = false}) async {
    final ids = await context.push<List<String>>(
      single ? AppRoutes.exercisePickerSingle : AppRoutes.exercisePicker,
    );
    return ids ?? const [];
  }

  /// Katalog z repozytorium (provider bez słuchaczy jest wstrzymany).
  Future<List<Exercise>> _catalog() =>
      ref.read(exerciseRepositoryProvider).findAll(includeArchived: true);

  Future<void> _addExercises() async {
    final ids = await _pickExercises();
    if (ids.isEmpty) return;
    final catalog = await _catalog();
    final byId = {for (final e in catalog) e.id: e};
    final added = await _controller.addExercises([
      for (final id in ids) ?byId[id],
    ]);
    if (!mounted || added == null) return;
    setState(() => _currentId = added);
  }

  /// Zamiana czyści zatwierdzone serie, więc wymaga potwierdzenia.
  Future<bool> _confirmReplace(SessionExercise current) async {
    if (!current.sets.any((s) => s.isCompleted)) return true;
    final l10n = AppLocalizations.of(context);
    return _confirmDialog(
      title: l10n.workoutReplaceTitle,
      message: l10n.workoutReplaceMessage(current.exerciseNameSnapshot),
      action: l10n.workoutReplaceConfirm,
      destructive: true,
    );
  }

  /// Zamiennik z podpowiedzi (ADR 0016): przypięte i podobne ćwiczenia;
  /// „Wybierz z całej biblioteki” prowadzi do zwykłej zamiany.
  Future<void> _substitute(SessionExercise current) async {
    final catalog = await _catalog();
    final target = catalog.firstWhereOrNull((e) => e.id == current.exerciseId);
    if (!mounted) return;
    if (target == null) return _replace(current);
    final history = ref.read(completedSessionsProvider).value ?? const [];
    final choice = await showSubstituteSheet(
      context,
      target: target,
      catalog: catalog,
      used: {
        for (final session in history)
          for (final e in session.exercises) e.exerciseId,
      },
    );
    if (!mounted) return;
    switch (choice) {
      case null:
        return;
      case SubstituteLibrary():
        await _replace(current);
      case SubstitutePicked(:final exercise):
        if (!await _confirmReplace(current)) return;
        await _controller.replaceExercise(current.id, exercise);
    }
  }

  Future<void> _replace(SessionExercise current) async {
    if (!await _confirmReplace(current)) return;
    final ids = await _pickExercises(single: true);
    if (ids.isEmpty) return;
    final catalog = await _catalog();
    final replacement = catalog.firstWhereOrNull((e) => e.id == ids.first);
    if (replacement == null) return;
    await _controller.replaceExercise(current.id, replacement);
  }

  Future<void> _remove(SessionExercise current) async {
    final l10n = AppLocalizations.of(context);
    final ok = await _confirmDialog(
      title: l10n.workoutRemoveExerciseTitle(current.exerciseNameSnapshot),
      message: null,
      action: l10n.commonDelete,
      destructive: true,
    );
    if (ok) await _controller.removeExercise(current.id);
  }

  void _openFinish() => unawaited(context.push(AppRoutes.workoutFinish));

  Future<void> _discard() async {
    final l10n = AppLocalizations.of(context);
    final rootMessenger = ScaffoldMessenger.of(context);
    final ok = await _confirmDialog(
      title: l10n.workoutDiscardTitle,
      message: l10n.workoutDiscardMessage,
      action: l10n.workoutDiscardConfirm,
      destructive: true,
    );
    if (!ok || !mounted) return;
    _leaving = true;
    await _controller.discard();
    if (!mounted) return;
    rootMessenger.showSnackBar(
      SnackBar(content: Text(l10n.workoutDiscardedSnack)),
    );
    context.go(AppRoutes.home);
  }

  Future<bool> _confirmDialog({
    required String title,
    required String? message,
    required String action,
    bool destructive = false,
  }) async {
    final l10n = AppLocalizations.of(context);
    final error = Theme.of(context).colorScheme.error;
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: message == null ? null : Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            style: destructive
                ? TextButton.styleFrom(foregroundColor: error)
                : null,
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(action),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  /// Sesja zniknęła (zakończona albo porzucona gdzie indziej): ekran
  /// treningu nie ma czego pokazać. Pusty strumień tuż po starcie treningu
  /// może być nieaktualny (baza działa w osobnym wątku), więc przed
  /// wyjściem stan jest sprawdzany w bazie.
  void _leaveWhenGone() {
    if (_leaving || _leavePending) return;
    _leavePending = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final active = await ref.read(workoutRepositoryProvider).findActive();
      _leavePending = false;
      if (!mounted || _leaving || active != null) return;
      if (!(ModalRoute.of(context)?.isCurrent ?? false)) return;
      _leaving = true;
      if (context.canPop()) {
        context.pop();
      } else {
        context.go(AppRoutes.home);
      }
    });
  }
}

class _Elapsed extends ConsumerWidget {
  const _Elapsed({required this.startedAt});

  final DateTime startedAt;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return TickerBuilder(
      builder: (context) {
        final now = ref.read(clockProvider).nowUtc();
        final seconds = max(0, now.difference(startedAt).inSeconds);
        return Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
            child: Text(
              formatClock(seconds),
              style: theme.textTheme.titleMedium?.copyWith(
                fontFeatures: AppTheme.tabularFigures,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _EmptyWorkout extends StatelessWidget {
  const _EmptyWorkout({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      children: [
        Expanded(
          child: EmptyState(
            icon: Icons.fitness_center_rounded,
            title: l10n.workoutEmptyTitle,
            message: l10n.workoutEmptyMessage,
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.gutter),
            child: SizedBox(
              width: double.infinity,
              height: AppSizes.primaryAction,
              child: FilledButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add_rounded),
                label: Text(l10n.workoutAddExercises),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Zmiana kolejności ćwiczeń w trakcie treningu. Lista w arkuszu zmienia
/// się od razu, a każda zmiana trafia do bazy.
class _ReorderSheet extends ConsumerStatefulWidget {
  const _ReorderSheet({required this.exercises});

  final List<SessionExercise> exercises;

  @override
  ConsumerState<_ReorderSheet> createState() => _ReorderSheetState();
}

class _ReorderSheetState extends ConsumerState<_ReorderSheet> {
  late var _order = List.of(widget.exercises);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
            child: Text(l10n.workoutReorder, style: theme.textTheme.titleLarge),
          ),
          const SizedBox(height: AppSpacing.s),
          Flexible(
            child: ReorderableListView.builder(
              shrinkWrap: true,
              buildDefaultDragHandles: false,
              itemCount: _order.length,
              onReorderItem: (from, to) {
                setState(() {
                  final order = List.of(_order);
                  order.insert(to, order.removeAt(from));
                  _order = order;
                });
                unawaited(
                  ref.read(workoutControllerProvider).moveExercise(from, to),
                );
              },
              itemBuilder: (context, index) {
                final exercise = _order[index];
                final name = exercise.exerciseNameSnapshot;
                return ListTile(
                  key: ValueKey(exercise.id),
                  title: Text(name),
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
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
