import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/routes.dart';
import '../../../core/database/database_providers.dart';
import '../../../core/domain/local_date.dart';
import '../../../core/domain/units.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/active_workout_dialog.dart';
import '../../exercises/data/exercise_providers.dart';
import '../../exercises/domain/exercise.dart';
import '../../history/presentation/history_labels.dart';
import '../../settings/data/settings_providers.dart';
import '../../settings/domain/app_settings.dart';
import '../../templates/data/template_providers.dart';
import '../../templates/domain/template.dart';
import '../../workout/data/workout_providers.dart';
import '../../workout/domain/workout_session.dart';
import '../data/plan_providers.dart';
import '../domain/plan.dart';
import '../domain/plan_schedule.dart';
import 'plan_labels.dart';
import 'plan_sheets.dart';
import 'plan_widgets.dart';

enum _View { month, week }

/// Czas na „Cofnij” po przesunięciu albo pominięciu treningu.
const _undoDuration = Duration(seconds: 6);

/// Zakładka „Plan” (ADR 0015): realizacja tygodnia, kalendarz miesiąca albo
/// lista tygodnia i karta wybranego dnia z krótkim opisem treningów.
class PlanScreen extends ConsumerStatefulWidget {
  const PlanScreen({super.key});

  @override
  ConsumerState<PlanScreen> createState() => _PlanScreenState();
}

class _PlanScreenState extends ConsumerState<PlanScreen> {
  _View _view = _View.month;
  LocalDate? _selected;
  LocalDate? _month;
  LocalDate? _week;

  LocalDate _today() {
    final now = ref.read(clockProvider).nowUtc().toLocal();
    return LocalDate(now.year, now.month, now.day);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final plan = ref.watch(planProvider).value;
    final history = ref.watch(completedSessionsProvider).value;
    final templates = ref.watch(templatesProvider).value;
    final catalog = ref.watch(exercisesByIdProvider).value ?? const {};
    final settings =
        ref.watch(appSettingsProvider).value ?? const AppSettings();
    final appBar = AppBar(
      title: Text(l10n.planTitle),
      actions: [
        IconButton(
          tooltip: l10n.planToday,
          icon: const Icon(Icons.today_rounded),
          onPressed: () => setState(() {
            final today = _today();
            _selected = today;
            _month = monthStart(today);
            _week = today.startOfWeek;
          }),
        ),
        IconButton(
          tooltip: l10n.planEditWeek,
          icon: const Icon(Icons.edit_calendar_rounded),
          onPressed: () => context.push(AppRoutes.planWeek),
        ),
      ],
    );
    if (plan == null || history == null || templates == null) {
      return Scaffold(
        appBar: appBar,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final today = _today();
    final selected = _selected ?? today;
    final month = _month ?? monthStart(today);
    final week = _week ?? today.startOfWeek;
    final byDate = sessionsByDate(history);
    DayOverview overview(LocalDate date) =>
        dayOverview(plan, byDate, date, today);
    final data = _PlanData(
      plan: plan,
      templates: {for (final t in templates) t.id: t},
      catalog: catalog,
      settings: settings,
      today: today,
    );
    final locale = Localizations.localeOf(context).toString();

    return Scaffold(
      appBar: appBar,
      body: ListView(
        key: const PageStorageKey('plan'),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.gutter,
          AppSpacing.s,
          AppSpacing.gutter,
          AppSpacing.xl,
        ),
        children: [
          if (currentWeeklyPlan(plan.weekly, today) == null &&
              plan.days.isEmpty)
            _NoPlanCard(onEdit: () => context.push(AppRoutes.planWeek))
          else
            _AdherenceCard(
              adherence: weekAdherence(plan, byDate, today, today),
              streak: planStreak(plan, byDate, today),
            ),
          const SizedBox(height: AppSpacing.l),
          SegmentedButton<_View>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment(
                value: _View.month,
                icon: const Icon(Icons.calendar_month_rounded),
                label: Text(l10n.planViewMonth),
              ),
              ButtonSegment(
                value: _View.week,
                icon: const Icon(Icons.view_agenda_rounded),
                label: Text(l10n.planViewWeek),
              ),
            ],
            selected: {_view},
            onSelectionChanged: (s) => setState(() => _view = s.single),
          ),
          const SizedBox(height: AppSpacing.m),
          if (_view == _View.month) ...[
            MonthCalendar(
              month: month,
              today: today,
              selected: selected,
              overview: overview,
              semantics: (o) => _semantics(l10n, data, o, locale),
              onSelect: (date) => setState(() {
                _selected = date;
                _week = date.startOfWeek;
              }),
              onMonth: (offset) =>
                  setState(() => _month = monthStart(month, offset)),
            ),
            const SizedBox(height: AppSpacing.s),
            const PlanLegend(),
            const SizedBox(height: AppSpacing.l),
            _day(l10n, data, overview(selected)),
          ] else ...[
            Row(
              children: [
                IconButton(
                  tooltip: l10n.planPrevWeek,
                  icon: const Icon(Icons.chevron_left_rounded),
                  onPressed: () => setState(() => _week = week.addDays(-7)),
                ),
                Expanded(
                  child: Text(
                    weekRange(week, locale),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  tooltip: l10n.planNextWeek,
                  icon: const Icon(Icons.chevron_right_rounded),
                  onPressed: () => setState(() => _week = week.addDays(7)),
                ),
              ],
            ),
            for (var i = 0; i < 7; i++) ...[
              const SizedBox(height: AppSpacing.m),
              _day(l10n, data, overview(week.addDays(i))),
            ],
          ],
        ],
      ),
    );
  }

  String _semantics(
    AppLocalizations l10n,
    _PlanData data,
    DayOverview overview,
    String locale,
  ) {
    final parts = [
      for (final entry in overview.entries)
        '${data.templateName(l10n, entry.item.templateId)}: '
            '${l10n.planStatus(entry.status).toLowerCase()}',
      for (final session in overview.extra)
        '${session.title ?? session.templateNameSnapshot ?? l10n.workoutTitle}: '
            '${l10n.planStatusExtra.toLowerCase()}',
    ];
    return l10n.planDaySemantics(
      longDate(overview.date, locale),
      parts.isEmpty ? l10n.planDayNothing : parts.join(', '),
    );
  }

  /// Karta dnia: tytuł, treningi z planu, treningi spoza planu i akcje.
  Widget _day(AppLocalizations l10n, _PlanData data, DayOverview overview) {
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toString();
    final date = longDate(overview.date, locale);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(
            overview.date == data.today ? l10n.planDayTitleToday(date) : date,
            style: theme.textTheme.titleMedium,
          ),
        ),
        if (overview.plan.fromDate)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xxs),
            child: Text(l10n.planFromDate, style: muted),
          ),
        const SizedBox(height: AppSpacing.s),
        for (final (index, entry) in overview.entries.indexed)
          if (entry.session case final session?)
            _SessionCard(
              session: session,
              status: entry.status,
              unit: data.settings.weightUnit,
            )
          else
            _PlannedCard(
              template: data.templates[entry.item.templateId],
              status: entry.status,
              data: data,
              onStart: _start,
              onPreview: (template) => unawaited(
                showTemplatePreview(
                  context,
                  template: template,
                  catalog: data.catalog,
                  onStart: entry.status == PlanStatus.today
                      ? () => _start(template)
                      : null,
                ),
              ),
              onAction: (action) =>
                  unawaited(_entryAction(data, overview, index, action)),
            ),
        for (final session in overview.extra)
          _SessionCard(
            session: session,
            extra: true,
            unit: data.settings.weightUnit,
          ),
        if (overview.entries.isEmpty && overview.extra.isEmpty)
          Card(
            child: ListTile(
              leading: const Icon(Icons.self_improvement_rounded),
              title: Text(l10n.planRestDay),
            ),
          ),
        Wrap(
          spacing: AppSpacing.s,
          children: [
            TextButton.icon(
              icon: const Icon(Icons.add_rounded),
              label: Text(
                overview.entries.isEmpty
                    ? l10n.planSchedule
                    : l10n.planAddWorkout,
              ),
              onPressed: () => unawaited(_schedule(data, overview.date)),
            ),
            if (overview.plan.fromDate)
              TextButton.icon(
                icon: const Icon(Icons.restore_rounded),
                label: Text(l10n.planRestoreWeekly),
                onPressed: () => unawaited(
                  ref.read(planRepositoryProvider).setDay(overview.date, []),
                ),
              ),
          ],
        ),
      ],
    );
  }

  // ------------------------------------------------------------ akcje

  Future<void> _start(Template template) async {
    final starter = ref.read(workoutStarterProvider);
    final started = await starter.startFromTemplate(template);
    if (!mounted) return;
    if (started || await showActiveWorkoutDialog(context)) {
      if (mounted) await context.push(AppRoutes.workout);
    }
  }

  Future<void> _schedule(_PlanData data, LocalDate date) async {
    final template = await pickTemplate(
      context,
      templates: data.activeTemplates,
      preview: data.previewLine,
    );
    if (template == null) return;
    await ref
        .read(planRepositoryProvider)
        .setDay(
          date,
          scheduleOn(
            dayPlan(data.plan, date),
            template.id,
            ref.read(idGeneratorProvider),
          ),
        );
  }

  Future<void> _entryAction(
    _PlanData data,
    DayOverview overview,
    int index,
    PlanEntryAction action,
  ) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final locale = Localizations.localeOf(context).toString();
    final repo = ref.read(planRepositoryProvider);
    final ids = ref.read(idGeneratorProvider);
    final day = overview.plan;

    /// Wpisy dni sprzed zmiany, do „Cofnij”.
    List<PlannedDay> entriesOf(LocalDate date) => [
      for (final d in data.plan.days)
        if (d.date == date) d,
    ];
    SnackBarAction undo(Map<LocalDate, List<PlannedDay>> before) =>
        SnackBarAction(
          label: l10n.planUndo,
          onPressed: () => unawaited(repo.setDays(before)),
        );
    switch (action) {
      case PlanEntryAction.moveTomorrow || PlanEntryAction.moveTo:
        final target = action == PlanEntryAction.moveTomorrow
            ? day.date.addDays(1)
            : await _pickDate(day.date.addDays(1));
        if (target == null || target == day.date) return;
        final before = {
          day.date: entriesOf(day.date),
          target: entriesOf(target),
        };
        final moved = moveItem(day, index, dayPlan(data.plan, target), ids);
        await repo.setDays({day.date: moved.from, target: moved.to});
        messenger.showSnackBar(
          SnackBar(
            action: undo(before),
            // Z akcją snackbar domyślnie zostaje; tu ma zniknąć sam.
            persist: false,
            duration: _undoDuration,
            content: Text(
              l10n.planMoved(
                DateFormat.MMMEd(locale)
                    .format(DateTime(target.year, target.month, target.day)),
              ),
            ),
          ),
        );
      case PlanEntryAction.replace:
        if (!mounted) return;
        final template = await pickTemplate(
          context,
          templates: data.activeTemplates,
          preview: data.previewLine,
        );
        if (template == null) return;
        await repo.setDay(day.date, replaceItem(day, index, template.id, ids));
      case PlanEntryAction.skip:
        final before = {day.date: entriesOf(day.date)};
        await repo.setDay(day.date, skipItem(day, index, ids));
        messenger.showSnackBar(
          SnackBar(
            action: undo(before),
            persist: false,
            duration: _undoDuration,
            content: Text(l10n.planSkipped),
          ),
        );
    }
  }

  Future<LocalDate?> _pickDate(LocalDate initial) async {
    final today = _today();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(initial.year, initial.month, initial.day),
      firstDate: DateTime(today.year - 1, today.month, today.day),
      lastDate: DateTime(today.year + 1, today.month, today.day),
    );
    return picked == null
        ? null
        : LocalDate(picked.year, picked.month, picked.day);
  }
}

/// Dane wspólne kart planu.
final class _PlanData {
  _PlanData({
    required this.plan,
    required this.templates,
    required this.catalog,
    required this.settings,
    required this.today,
  });

  final PlanState plan;

  /// Szablony po id, także zarchiwizowane.
  final Map<String, Template> templates;
  final Map<String, Exercise> catalog;
  final AppSettings settings;
  final LocalDate today;

  List<Template> get activeTemplates => [
    for (final t in templates.values)
      if (!t.isArchived) t,
  ];

  String templateName(AppLocalizations l10n, String id) =>
      templates[id]?.name ?? l10n.planDeletedTemplate;

  TemplatePreview preview(Template template) => templatePreview(
    template,
    defaultRestSeconds: settings.defaultRestSeconds,
  );

  String previewLine(AppLocalizations l10n, Template template) {
    final p = preview(template);
    return l10n.planPreviewLine(p.exercises, p.sets, p.minutes);
  }
}

class _NoPlanCard extends StatelessWidget {
  const _NoPlanCard({required this.onEdit});

  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.l),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.planNoPlanTitle, style: theme.textTheme.titleMedium),
            const SizedBox(height: AppSpacing.s),
            Text(
              l10n.planNoPlanBody,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.m),
            FilledButton.icon(
              icon: const Icon(Icons.edit_calendar_rounded),
              label: Text(l10n.planEditWeek),
              onPressed: onEdit,
            ),
          ],
        ),
      ),
    );
  }
}

class _AdherenceCard extends StatelessWidget {
  const _AdherenceCard({required this.adherence, required this.streak});

  final Adherence adherence;
  final int streak;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final (:done, :planned, :remaining) = adherence;
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final status = planned > 0 && done >= planned
        ? l10n.planWeekDone
        : remaining > 0
        ? l10n.planRemaining(remaining)
        : null;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.l),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.planThisWeek,
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              l10n.planAdherence(done, planned),
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.s),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: planned == 0 ? 0 : done / planned,
                minHeight: 8,
                color: planAccent(context),
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
              ),
            ),
            if (status != null || streak > 0) ...[
              const SizedBox(height: AppSpacing.s),
              // Przy dużej czcionce seria przechodzi do nowej linii.
              Wrap(
                spacing: AppSpacing.l,
                runSpacing: AppSpacing.xs,
                children: [
                  if (status != null) Text(status, style: muted),
                  if (streak > 0)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.local_fire_department_rounded,
                          size: 18,
                          color: planAccent(context),
                        ),
                        const SizedBox(width: AppSpacing.xxs),
                        Flexible(
                          child: Text(l10n.planStreak(streak), style: muted),
                        ),
                      ],
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Zaplanowany trening: nazwa, stan, krótki opis i „Rozpocznij” na dziś.
class _PlannedCard extends StatelessWidget {
  const _PlannedCard({
    required this.template,
    required this.status,
    required this.data,
    required this.onStart,
    required this.onPreview,
    required this.onAction,
  });

  final Template? template;
  final PlanStatus status;
  final _PlanData data;
  final ValueChanged<Template> onStart;
  final ValueChanged<Template> onPreview;
  final ValueChanged<PlanEntryAction> onAction;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final template = this.template;
    final preview = template == null ? null : data.preview(template);
    final names = [
      for (final id in preview?.exerciseIds ?? const <String>[])
        ?data.catalog[id]?.name,
    ];
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.m),
        onTap: template == null ? null : () => onPreview(template),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.l,
            AppSpacing.s,
            AppSpacing.xs,
            AppSpacing.m,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      template?.name ?? l10n.planDeletedTemplate,
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  PopupMenuButton<PlanEntryAction>(
                    tooltip: l10n.planEntryMenu,
                    onSelected: onAction,
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: PlanEntryAction.moveTomorrow,
                        child: Text(l10n.planMoveTomorrow),
                      ),
                      PopupMenuItem(
                        value: PlanEntryAction.moveTo,
                        child: Text(l10n.planMoveTo),
                      ),
                      PopupMenuItem(
                        value: PlanEntryAction.replace,
                        child: Text(l10n.planReplace),
                      ),
                      PopupMenuItem(
                        value: PlanEntryAction.skip,
                        child: Text(l10n.planSkip),
                      ),
                    ],
                  ),
                ],
              ),
              PlanStatusChip(status: status),
              if (preview != null && preview.sets > 0) ...[
                const SizedBox(height: AppSpacing.s),
                Text(
                  l10n.planPreviewLine(
                    preview.exercises,
                    preview.sets,
                    preview.minutes,
                  ),
                  style: theme.textTheme.bodyMedium,
                ),
                if (names.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(
                      top: AppSpacing.xxs,
                      right: AppSpacing.m,
                    ),
                    child: Text(
                      [
                        ...names.take(3),
                        if (names.length > 3)
                          l10n.planMoreExercises(names.length - 3),
                      ].join(', '),
                      style: muted,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              if (status == PlanStatus.today && template != null) ...[
                const SizedBox(height: AppSpacing.m),
                FilledButton.icon(
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: Text(l10n.planStart),
                  onPressed: () => onStart(template),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Zakończony trening: tytuł, stan, godzina i podsumowanie. Dotknięcie
/// otwiera szczegóły.
class _SessionCard extends StatelessWidget {
  const _SessionCard({
    required this.session,
    required this.unit,
    this.status,
    this.extra = false,
  });

  final WorkoutSession session;
  final WeightUnit unit;
  final PlanStatus? status;
  final bool extra;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toString();
    // Godzina w strefie zapisanej przy starcie treningu, jak w historii.
    final local = localTimeFor(session.startedAt, session.timeZone);
    final time =
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.m),
        onTap: () => context.push(AppRoutes.sessionDetail(session.id)),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.l),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      session.title ??
                          session.templateNameSnapshot ??
                          l10n.workoutTitle,
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded),
                ],
              ),
              PlanStatusChip(status: status, extra: extra),
              const SizedBox(height: AppSpacing.s),
              Text(
                '$time · ${l10n.sessionSummary(session, unit, locale)}',
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
