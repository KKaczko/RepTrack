import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/database/database_providers.dart';
import '../../../core/domain/units.dart';
import '../../../core/l10n/formatters.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../exercises/data/exercise_providers.dart';
import '../../exercises/domain/exercise.dart';
import '../../progress/domain/metrics.dart';
import '../../settings/data/settings_providers.dart';
import '../../templates/data/template_providers.dart';
import '../../templates/domain/template.dart';
import '../data/workout_providers.dart';
import '../domain/session_summary.dart';
import '../domain/template_sync.dart';
import 'workout_controller.dart';

/// Rekordy pobite w sesji względem pozostałej historii.
final _recordsProvider = FutureProvider.autoDispose
    .family<List<SessionRecord>, String>((ref, sessionId) async {
      final repo = ref.watch(workoutRepositoryProvider);
      final session = await repo.findById(sessionId);
      if (session == null) return const [];
      final history = await repo.completedSetsFor({
        for (final e in session.exercises) e.exerciseId,
      }, excludeSessionId: sessionId);
      return sessionRecords(session, history);
    });

/// Zakończenie treningu (spec. 5.3): podsumowanie, nowe rekordy, notatka,
/// samopoczucie i opcjonalna aktualizacja szablonu po potwierdzeniu.
class FinishWorkoutScreen extends ConsumerStatefulWidget {
  const FinishWorkoutScreen({super.key});

  @override
  ConsumerState<FinishWorkoutScreen> createState() =>
      _FinishWorkoutScreenState();
}

class _FinishWorkoutScreenState extends ConsumerState<FinishWorkoutScreen> {
  final _notes = TextEditingController();
  int? _wellbeing;
  bool _updateTemplate = false;
  bool _saving = false;

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final session = ref.watch(activeSessionProvider).value;
    if (session == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final unit =
        ref.watch(appSettingsProvider).value?.weightUnit ?? WeightUnit.kg;
    final locale = Localizations.localeOf(context).toString();
    final summary = summarizeSession(session, ref.read(clockProvider).nowUtc());
    final template = session.templateId == null
        ? null
        : ref
              .watch(templatesProvider)
              .value
              ?.firstWhereOrNull((t) => t.id == session.templateId);
    final changes = template == null
        ? const <TemplateChange>[]
        : diffSessionAgainstTemplate(template, session);
    final records = ref.watch(_recordsProvider(session.id)).value ?? const [];
    final names = ref.watch(exercisesByIdProvider).value ?? const {};
    final open = openSetCount(session);
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    return Scaffold(
      appBar: AppBar(title: Text(l10n.finishTitle)),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.gutter,
                AppSpacing.s,
                AppSpacing.gutter,
                AppSpacing.xl,
              ),
              children: [
                if (session.title case final title?)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.m),
                    child: Text(title, style: theme.textTheme.titleLarge),
                  ),
                _StatsGrid(
                  stats: [
                    (
                      l10n.finishDuration,
                      formatClock(summary.duration.inSeconds),
                    ),
                    (
                      l10n.finishVolume,
                      formatVolume(summary.volumeG, unit, locale),
                    ),
                    (l10n.finishSets, '${summary.completedSets}'),
                    (l10n.finishExercises, '${summary.exercisesDone}'),
                  ],
                ),
                if (open > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.m),
                    child: Text(l10n.finishIncomplete(open), style: muted),
                  ),
                if (records.isNotEmpty) ...[
                  _SectionTitle(l10n.finishRecords),
                  for (final record in records)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        Icons.emoji_events_rounded,
                        color: context.appColors.accentFill,
                      ),
                      title: Text(_recordLabel(l10n, record, unit, locale)),
                    ),
                ],
                _SectionTitle(l10n.finishNotes),
                TextField(
                  controller: _notes,
                  textCapitalization: TextCapitalization.sentences,
                  minLines: 2,
                  maxLines: 5,
                  decoration: InputDecoration(hintText: l10n.finishNotes),
                ),
                _SectionTitle(l10n.finishWellbeing),
                SegmentedButton<int>(
                  segments: [
                    for (var i = 1; i <= 5; i++)
                      ButtonSegment(
                        value: i,
                        label: Text('$i'),
                        tooltip: l10n.finishWellbeingValue(i),
                      ),
                  ],
                  selected: {?_wellbeing},
                  emptySelectionAllowed: true,
                  showSelectedIcon: false,
                  onSelectionChanged: (selection) =>
                      setState(() => _wellbeing = selection.firstOrNull),
                ),
                if (template != null && changes.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.l),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    value: _updateTemplate,
                    onChanged: (value) =>
                        setState(() => _updateTemplate = value ?? false),
                    title: Text(l10n.finishUpdateTemplate(template.name)),
                    subtitle: Text(l10n.finishUpdateTemplateHint),
                  ),
                  for (final change in changes)
                    Padding(
                      padding: const EdgeInsets.only(
                        left: AppSizes.minTouch + AppSpacing.s,
                        bottom: AppSpacing.xs,
                      ),
                      child: Text(
                        '• ${_changeLabel(l10n, change, names)}',
                        style: muted,
                      ),
                    ),
                ],
              ],
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
                  onPressed: _saving ? null : () => _save(template),
                  icon: const Icon(Icons.flag_rounded),
                  label: Text(l10n.finishSave),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _save(Template? template) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _saving = true);
    await ref
        .read(workoutControllerProvider)
        .finish(
          notes: _notes.text,
          wellbeing: _wellbeing,
          templateToUpdate: _updateTemplate ? template : null,
        );
    if (!mounted) return;
    context.go(AppRoutes.home);
    messenger.showSnackBar(SnackBar(content: Text(l10n.finishSavedSnack)));
  }

  static String _recordLabel(
    AppLocalizations l10n,
    SessionRecord record,
    WeightUnit unit,
    String locale,
  ) {
    final name = record.exerciseName;
    return switch (record.event) {
      E1rmRecord(:final e1rmG) => l10n.recordE1rm(
        name,
        formatEstimate(e1rmG, unit, locale),
      ),
      RepsWeightRecord(:final reps, :final weightG) => l10n.recordRepsWeight(
        name,
        formatWeight(weightG, unit, locale),
        reps,
      ),
      MaxRepsRecord(:final reps) => l10n.recordMaxReps(name, reps),
    };
  }

  static String _changeLabel(
    AppLocalizations l10n,
    TemplateChange change,
    Map<String, Exercise> names,
  ) => switch (change) {
    ExerciseAdded(:final name) => l10n.changeAdded(name),
    ExerciseRemoved(:final exerciseId) => l10n.changeRemoved(
      names[exerciseId]?.name ?? '…',
    ),
    ExerciseReplaced(:final fromExerciseId, :final toName) =>
      l10n.changeReplaced(names[fromExerciseId]?.name ?? '…', toName),
    SetCountChanged(:final name, :final from, :final to) => l10n.changeSetCount(
      name,
      from,
      to,
    ),
    OrderChanged() => l10n.changeOrder,
  };
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: AppSpacing.xl, bottom: AppSpacing.s),
    child: Text(text, style: Theme.of(context).textTheme.titleMedium),
  );
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.stats});

  final List<(String, String)> stats;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Wrap(
      spacing: AppSpacing.s,
      runSpacing: AppSpacing.s,
      children: [
        for (final (label, value) in stats)
          LayoutBuilder(
            builder: (context, constraints) => SizedBox(
              width:
                  (MediaQuery.sizeOf(context).width -
                      2 * AppSpacing.gutter -
                      AppSpacing.s) /
                  2,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.m),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          value,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontFeatures: AppTheme.tabularFigures,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
