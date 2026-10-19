import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/routes.dart';
import '../../../core/database/database_providers.dart';
import '../../../core/domain/local_date.dart';
import '../../../core/domain/units.dart';
import '../../../core/l10n/formatters.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/active_workout_dialog.dart';
import '../../history/domain/history_queries.dart';
import '../../settings/data/settings_providers.dart';
import '../../templates/data/template_providers.dart';
import '../../templates/domain/template.dart';
import '../../workout/data/workout_providers.dart';
import '../../workout/domain/session_summary.dart';
import '../../workout/domain/workout_session.dart';

/// Ekran Start (spec. 7): wznowienie trwającego treningu, szybki start
/// ostatniego szablonu, inne szablony, pusty trening, ostatni trening
/// i liczba treningów w tym tygodniu.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final active = ref.watch(activeSessionProvider).value;
    final history = ref.watch(completedSessionsProvider).value ?? const [];
    final templates = ref.watch(templatesProvider).value ?? const [];
    final ordered = _templatesForStart(templates, history);
    final now = ref.watch(clockProvider).nowUtc().toLocal();
    final today = LocalDate(now.year, now.month, now.day);
    final thisWeek = history
        .where((s) => s.localDate.startOfWeek == today.startOfWeek)
        .length;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appTitle),
        actions: [
          IconButton(
            tooltip: l10n.openSettings,
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push(AppRoutes.settings),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.gutter),
        children: [
          if (active != null)
            _ResumeCard(session: active)
          else ...[
            if (ordered.firstOrNull case final quick?)
              SizedBox(
                height: AppSizes.primaryAction,
                child: FilledButton.icon(
                  onPressed: () => _start(context, ref, quick),
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: Text(
                    l10n.homeQuickStart(quick.name),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.s),
                child: Text(
                  l10n.homeNoTemplates,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            const SizedBox(height: AppSpacing.s),
            SizedBox(
              height: AppSizes.stepper,
              child: OutlinedButton.icon(
                onPressed: () => _start(context, ref, null),
                icon: const Icon(Icons.add_rounded),
                label: Text(l10n.startEmptyWorkout),
              ),
            ),
            if (ordered.length > 1) ...[
              _SectionTitle(l10n.homeOtherTemplates),
              for (final template in ordered.skip(1).take(3))
                ListTile(
                  contentPadding: const EdgeInsets.only(left: AppSpacing.xs),
                  title: Text(template.name),
                  subtitle: Text(
                    l10n.exercisesCount(template.exercises.length),
                  ),
                  trailing: IconButton(
                    tooltip: l10n.workoutStart,
                    icon: const Icon(Icons.play_arrow_rounded),
                    onPressed: () => _start(context, ref, template),
                  ),
                  onTap: () => _start(context, ref, template),
                ),
            ],
          ],
          _SectionTitle(l10n.homeThisWeek),
          Text(
            l10n.workoutsCount(thisWeek),
            style: Theme.of(context).textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          if (history.firstOrNull case final last?) ...[
            _SectionTitle(l10n.homeLastSession),
            _LastSessionCard(session: last),
          ],
        ],
      ),
    );
  }

  /// Szablony do startu: najpierw ostatnio używane, potem pozostałe
  /// alfabetycznie. Pomija zarchiwizowane i puste.
  static List<Template> _templatesForStart(
    List<Template> templates,
    List<WorkoutSession> history,
  ) {
    final usable = {
      for (final t in templates)
        if (!t.isArchived && t.exercises.isNotEmpty) t.id: t,
    };
    final recent = [
      for (final id in templatesByLastUse(history)) ?usable.remove(id),
    ];
    return [...recent, ...usable.values];
  }

  Future<void> _start(
    BuildContext context,
    WidgetRef ref,
    Template? template,
  ) async {
    final starter = ref.read(workoutStarterProvider);
    final started = template == null
        ? await starter.startEmpty()
        : await starter.startFromTemplate(template);
    if (!context.mounted) return;
    if (started || await showActiveWorkoutDialog(context)) {
      if (context.mounted) await context.push(AppRoutes.workout);
    }
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xl, bottom: AppSpacing.s),
      child: Text(
        text,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }
}

class _LastSessionCard extends ConsumerWidget {
  const _LastSessionCard({required this.session});

  final WorkoutSession session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toString();
    final unit =
        ref.watch(appSettingsProvider).value?.weightUnit ?? WeightUnit.kg;
    final summary = summarizeSession(
      session,
      session.endedAt ?? session.startedAt,
    );
    final date = DateFormat.MMMEd(locale).format(
      DateTime(
        session.localDate.year,
        session.localDate.month,
        session.localDate.day,
      ),
    );
    final minutes = summary.duration.inMinutes;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.l,
          vertical: AppSpacing.xs,
        ),
        title: Text(session.title ?? l10n.workoutTitle),
        subtitle: Text(
          [
            date,
            minutes < 60
                ? l10n.durationMinutes(minutes)
                : l10n.durationHoursMinutes(minutes ~/ 60, minutes % 60),
            l10n.setCount(summary.completedSets),
            if (summary.volumeG > 0)
              formatVolume(summary.volumeG, unit, locale),
          ].join(' · '),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontFeatures: AppTheme.tabularFigures,
          ),
        ),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () => context.push(AppRoutes.sessionDetail(session.id)),
      ),
    );
  }
}

class _ResumeCard extends StatelessWidget {
  const _ResumeCard({required this.session});

  final WorkoutSession session;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final time = localTimeFor(session.startedAt, session.timeZone);
    final started =
        '${time.hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')}';
    return Card(
      color: context.appColors.surfaceRaised,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.l),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.homeResumeTitle, style: theme.textTheme.titleMedium),
            const SizedBox(height: AppSpacing.xs),
            Text(
              l10n.homeResumeMessage(
                session.title ?? l10n.workoutTitle,
                started,
              ),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.m),
            SizedBox(
              height: AppSizes.stepper,
              child: FilledButton.icon(
                onPressed: () => context.push(AppRoutes.workout),
                icon: const Icon(Icons.play_arrow_rounded),
                label: Text(l10n.homeResume),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
