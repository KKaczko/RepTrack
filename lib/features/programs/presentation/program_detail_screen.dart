import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/database/database_providers.dart';
import '../../../core/domain/exercise_groups.dart';
import '../../../core/domain/local_date.dart';
import '../../../core/l10n/formatters.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/superset_badge.dart';
import '../../plan/data/plan_providers.dart';
import '../../plan/domain/plan_schedule.dart';
import '../../plan/presentation/plan_labels.dart';
import '../data/program_providers.dart';
import '../domain/program.dart';
import 'program_labels.dart';

/// Podgląd programu: opis, plan tygodnia, treningi z seriami i „Dodaj
/// program” (ADR 0019).
class ProgramDetailScreen extends ConsumerStatefulWidget {
  const ProgramDetailScreen({required this.programId, super.key});

  final String programId;

  @override
  ConsumerState<ProgramDetailScreen> createState() =>
      _ProgramDetailScreenState();
}

class _ProgramDetailScreenState extends ConsumerState<ProgramDetailScreen> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final programs = ref.watch(programLibraryProvider).value;
    final exercises = ref.watch(programExercisesProvider).value;
    final program = programs?.firstWhereOrNull((p) => p.id == widget.programId);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.programsTitle)),
      body: program == null || exercises == null
          ? const Center(child: CircularProgressIndicator())
          : _body(context, program, {
              for (final MapEntry(:key, :value) in exercises.entries)
                key: value.name,
            }),
      bottomNavigationBar: program == null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.gutter),
                child: SizedBox(
                  height: AppSizes.primaryAction,
                  child: FilledButton.icon(
                    icon: const Icon(Icons.playlist_add_rounded),
                    label: Text(l10n.programAdd),
                    onPressed: _busy ? null : () => _add(program),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _body(
    BuildContext context,
    Program program,
    Map<String, String> names,
  ) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final lang = l10n.localeName;
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final weekdays = program.schedule.keys.toList()..sort();
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.gutter),
      children: [
        Text(program.name.of(lang), style: theme.textTheme.headlineSmall),
        const SizedBox(height: AppSpacing.xs),
        Text(
          l10n.programSummary(program),
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: AppSpacing.s),
        Text(program.description.of(lang), style: theme.textTheme.bodyLarge),
        const SizedBox(height: AppSpacing.l),
        Text(l10n.programWeekTitle, style: theme.textTheme.titleMedium),
        const SizedBox(height: AppSpacing.xs),
        for (final weekday in weekdays)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Text(
              '${weekdayName(weekday, lang)}: '
              '${program.workout(program.schedule[weekday]!)?.name.of(lang)}',
            ),
          ),
        for (final workout in program.workouts) ...[
          const SizedBox(height: AppSpacing.l),
          Text(workout.name.of(lang), style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.xs),
          ..._exerciseRows(context, workout, names, muted),
        ],
      ],
    );
  }

  List<Widget> _exerciseRows(
    BuildContext context,
    ProgramWorkout workout,
    Map<String, String> names,
    TextStyle? muted,
  ) {
    final l10n = AppLocalizations.of(context);
    final groups = groupLabels([for (final e in workout.exercises) e.superset]);
    return [
      for (final (i, e) in workout.exercises.indexed)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (groups[i] case final label?) ...[
                SupersetBadge(label),
                const SizedBox(width: AppSpacing.s),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(names[e.exerciseKey] ?? e.exerciseKey),
                    Text(
                      l10n.programExerciseLine(
                        e.sets,
                        formatTarget(e.targetKind, e.targetMin, e.targetMax),
                        formatClock(e.restSeconds),
                      ),
                      style: muted,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
    ];
  }

  Future<void> _add(Program program) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    final plan = ref.read(planProvider).value;
    final now = ref.read(clockProvider).nowUtc().toLocal();
    final today = LocalDate(now.year, now.month, now.day);
    if (plan != null && currentWeeklyPlan(plan.weekly, today) != null) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l10n.programReplacePlanTitle),
          content: Text(l10n.programReplacePlanMessage),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l10n.commonCancel),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(l10n.programReplaceConfirm),
            ),
          ],
        ),
      );
      if (ok != true || !mounted) return;
    }
    setState(() => _busy = true);
    try {
      await ref
          .read(programInstallerProvider)
          .install(program, languageCode: l10n.localeName);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    messenger.showSnackBar(
      SnackBar(
        content: Text(l10n.programAdded(program.name.of(l10n.localeName))),
      ),
    );
    router.go(AppRoutes.home);
  }
}
