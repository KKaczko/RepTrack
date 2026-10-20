import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/database/database_providers.dart';
import '../../../core/domain/training.dart';
import '../../../core/domain/units.dart';
import '../../../core/l10n/formatters.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/empty_state.dart';
import '../../exercises/data/exercise_providers.dart';
import '../../settings/data/settings_providers.dart';
import '../../workout/data/workout_providers.dart';
import '../../workout/domain/session_editing.dart';
import '../../workout/domain/session_summary.dart';
import '../../workout/domain/workout_session.dart';
import '../domain/session_corrections.dart';
import 'history_labels.dart';
import 'set_edit_sheet.dart';

/// Szczegóły zakończonego treningu z trybem edycji (spec. 5.4). Edycja
/// działa na kopii i zapisuje się przyciskiem „Zapisz”; tylko zmienione
/// wiersze dostają nowe `updated_at`.
class SessionDetailScreen extends ConsumerStatefulWidget {
  const SessionDetailScreen({required this.sessionId, super.key});

  final String sessionId;

  @override
  ConsumerState<SessionDetailScreen> createState() =>
      _SessionDetailScreenState();
}

class _SessionDetailScreenState extends ConsumerState<SessionDetailScreen> {
  final _messenger = GlobalKey<ScaffoldMessengerState>();
  final _notes = TextEditingController();

  /// Kopia robocza w trybie edycji; null poza edycją.
  WorkoutSession? _draft;
  WorkoutSession? _original;

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  bool get _dirty =>
      _draft != null &&
      (_draft != _original || (_notes.text.trim()) != (_original!.notes ?? ''));

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final history = ref.watch(completedSessionsProvider);
    final saved = history.value?.firstWhereOrNull(
      (s) => s.id == widget.sessionId,
    );
    if (saved == null) {
      return Scaffold(
        appBar: AppBar(),
        body: history.isLoading
            ? const Center(child: CircularProgressIndicator())
            : EmptyState(
                icon: Icons.search_off_rounded,
                title: l10n.sessionNotFound,
                message: '',
              ),
      );
    }
    final session = _draft ?? saved;
    final editing = _draft != null;

    return PopScope(
      canPop: !editing,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && editing) unawaited(_leaveEditing());
      },
      child: ScaffoldMessenger(
        key: _messenger,
        child: Scaffold(
          appBar: editing ? _editBar(l10n) : _viewBar(l10n, saved),
          body: _Body(
            session: session,
            editing: editing,
            notes: _notes,
            onChanged: (next) => setState(() => _draft = next),
            onNotesChanged: () => setState(() {}),
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _viewBar(AppLocalizations l10n, WorkoutSession session) =>
      AppBar(
        title: Text(session.title ?? l10n.workoutTitle),
        actions: [
          IconButton(
            tooltip: l10n.sessionCompare,
            icon: const Icon(Icons.compare_arrows_rounded),
            onPressed: () => context.push(AppRoutes.sessionCompare(session.id)),
          ),
          IconButton(
            tooltip: l10n.sessionEdit,
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => setState(() {
              _original = session;
              _draft = session;
              _notes.text = session.notes ?? '';
            }),
          ),
          PopupMenuButton<void>(
            tooltip: l10n.sessionMore,
            itemBuilder: (context) => [
              PopupMenuItem(
                onTap: () => unawaited(
                  context.push(AppRoutes.assistantReview(session.id)),
                ),
                child: Text(l10n.assistantReviewSession),
              ),
              PopupMenuItem(
                onTap: () => unawaited(_delete(session)),
                child: Text(l10n.sessionDelete),
              ),
            ],
          ),
        ],
      );

  PreferredSizeWidget _editBar(AppLocalizations l10n) => AppBar(
    leading: IconButton(
      tooltip: l10n.commonClose,
      icon: const Icon(Icons.close_rounded),
      onPressed: () => unawaited(_leaveEditing()),
    ),
    title: Text(l10n.sessionEditTitle),
    actions: [TextButton(onPressed: _save, child: Text(l10n.commonSave))],
  );

  /// Wyjście z edycji; przy zmianach z potwierdzeniem odrzucenia.
  Future<void> _leaveEditing() async {
    final l10n = AppLocalizations.of(context);
    if (_dirty) {
      final discard = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l10n.sessionDiscardTitle),
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
      if (discard != true) return;
    }
    if (mounted) setState(() => _draft = null);
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final draft = _draft;
    if (draft == null) return;
    final notes = _notes.text.trim();
    await ref
        .read(workoutRepositoryProvider)
        .save(draft.copyWith(notes: notes.isEmpty ? null : notes));
    if (!mounted) return;
    setState(() => _draft = null);
    _messenger.currentState?.showSnackBar(
      SnackBar(content: Text(l10n.sessionSavedSnack)),
    );
  }

  Future<void> _delete(WorkoutSession session) async {
    final l10n = AppLocalizations.of(context);
    final rootMessenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.sessionDeleteTitle),
        content: Text(l10n.sessionDeleteMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.commonDelete),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await ref.read(workoutRepositoryProvider).delete(session.id);
    if (!mounted) return;
    context.pop();
    rootMessenger.showSnackBar(
      SnackBar(content: Text(l10n.sessionDeletedSnack)),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({
    required this.session,
    required this.editing,
    required this.notes,
    required this.onChanged,
    required this.onNotesChanged,
  });

  final WorkoutSession session;
  final bool editing;
  final TextEditingController notes;
  final ValueChanged<WorkoutSession> onChanged;
  final VoidCallback onNotesChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toString();
    final unit =
        ref.watch(appSettingsProvider).value?.weightUnit ?? WeightUnit.kg;
    final catalog = ref.watch(exercisesByIdProvider).value ?? const {};
    final summary = summarizeSession(
      session,
      session.endedAt ?? session.startedAt,
    );
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.gutter,
        0,
        AppSpacing.gutter,
        AppSpacing.xxl,
      ),
      children: [
        Text(l10n.sessionWhen(session, locale), style: muted),
        if (session.templateNameSnapshot case final name?)
          Text(l10n.sessionTemplate(name), style: muted),
        const SizedBox(height: AppSpacing.m),
        Wrap(
          spacing: AppSpacing.xl,
          runSpacing: AppSpacing.s,
          children: [
            _Stat(l10n.finishDuration, l10n.duration(summary.duration)),
            _Stat(
              l10n.finishVolume,
              formatVolume(summary.volumeG, unit, locale),
            ),
            _Stat(l10n.finishSets, '${summary.completedSets}'),
          ],
        ),
        const SizedBox(height: AppSpacing.l),
        if (editing) ...[
          TextField(
            controller: notes,
            textCapitalization: TextCapitalization.sentences,
            minLines: 1,
            maxLines: 4,
            onChanged: (_) => onNotesChanged(),
            decoration: InputDecoration(labelText: l10n.finishNotes),
          ),
          const SizedBox(height: AppSpacing.m),
          Text(l10n.finishWellbeing, style: theme.textTheme.titleSmall),
          const SizedBox(height: AppSpacing.s),
          SegmentedButton<int>(
            segments: [
              for (var i = 1; i <= 5; i++)
                ButtonSegment(
                  value: i,
                  label: Text('$i'),
                  tooltip: l10n.finishWellbeingValue(i),
                ),
            ],
            selected: {?session.wellbeing},
            emptySelectionAllowed: true,
            showSelectedIcon: false,
            onSelectionChanged: (s) =>
                onChanged(session.copyWith(wellbeing: s.firstOrNull)),
          ),
        ] else ...[
          if (session.wellbeing case final value?)
            Text(l10n.sessionWellbeing(value), style: muted),
          if (session.notes case final text?)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.s),
              child: Text(text),
            ),
        ],
        for (final exercise in sortedExercises(session))
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.l),
            child: _ExerciseCard(
              session: session,
              exercise: exercise,
              name: l10n.exerciseName(exercise, catalog),
              editing: editing,
              unit: unit,
              onChanged: onChanged,
            ),
          ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        Text(
          value,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _ExerciseCard extends ConsumerWidget {
  const _ExerciseCard({
    required this.session,
    required this.exercise,
    required this.name,
    required this.editing,
    required this.unit,
    required this.onChanged,
  });

  final WorkoutSession session;
  final SessionExercise exercise;
  final String name;
  final bool editing;
  final WeightUnit unit;
  final ValueChanged<WorkoutSession> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toString();
    final m = exercise.measurementSnapshot;
    final sets = sortedSets(exercise);
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: context.appColors.textHint,
      fontFeatures: AppTheme.tabularFigures,
    );
    final strong = theme.textTheme.bodyLarge?.copyWith(
      fontWeight: FontWeight.w600,
      fontFeatures: AppTheme.tabularFigures,
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.s),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.l,
                vertical: AppSpacing.xs,
              ),
              child: Text(name, style: theme.textTheme.titleMedium),
            ),
            for (final set in sets)
              InkWell(
                onTap: editing ? () => _editSet(context, ref, set) : null,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    minHeight: AppSizes.minTouch,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.l,
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 36,
                          child: Text(
                            '${set.position + 1}'
                            '${_typeTag(l10n, set.setType)}',
                            style: muted,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            formatSetValues(
                                  unit: unit,
                                  locale: locale,
                                  weightG: m.weight ? set.weightG : null,
                                  reps: m.reps ? set.reps : null,
                                  durationS: m.duration ? set.durationS : null,
                                  distanceM: m.distance ? set.distanceM : null,
                                  metersUnit: l10n.workoutUnitMeters,
                                ) ??
                                '—',
                            style: set.isCompleted ? strong : muted,
                          ),
                        ),
                        // Wysiłek i „niezatwierdzona” ustępują miejsca
                        // wartościom przy dużej czcionce.
                        if ([
                              if (set.effortTenths case final tenths?)
                                '${set.effortScale == EffortScale.rpe ? l10n.effortRpe : l10n.effortRir} '
                                    '${formatDecimal(tenths / 10, locale)}',
                              if (!set.isCompleted) l10n.sessionSetOpenTag,
                            ].join(' · ')
                            case final tags when tags.isNotEmpty)
                          Flexible(
                            child: Padding(
                              padding: const EdgeInsets.only(
                                left: AppSpacing.s,
                              ),
                              child: Text(
                                tags,
                                style: muted,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.end,
                              ),
                            ),
                          ),
                        if (editing)
                          const Padding(
                            padding: EdgeInsets.only(left: AppSpacing.s),
                            child: Icon(Icons.edit_outlined, size: 18),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            if (editing)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => onChanged(
                      appendLoggedSet(
                        session,
                        exercise.id,
                        ref.read(idGeneratorProvider),
                      ),
                    ),
                    icon: const Icon(Icons.add_rounded),
                    label: Text(l10n.workoutAddSet),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  static String _typeTag(AppLocalizations l10n, SetType type) => switch (type) {
    SetType.warmup => l10n.setLabelWarmup,
    SetType.working => '',
    SetType.drop => l10n.setLabelDrop,
    SetType.amrap => l10n.setLabelAmrap,
  };

  Future<void> _editSet(
    BuildContext context,
    WidgetRef ref,
    SessionSet set,
  ) async {
    final scale = ref.read(appSettingsProvider).value?.effortScale;
    final result = await showSetEditSheet(
      context,
      set: set,
      measurement: exercise.measurementSnapshot,
      unit: unit,
      effortScale: set.effortScale ?? scale,
      session: session,
    );
    switch (result) {
      case SetEditSaved(:final set):
        onChanged(updateSet(session, exercise.id, set.id, (_) => set));
      case SetEditRemoved():
        onChanged(removeSet(session, exercise.id, set.id));
      case null:
        break;
    }
  }
}
