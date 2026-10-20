import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_providers.dart';
import '../../../core/domain/local_date.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/platform/plan_reminders.dart';
import '../../../core/theme/tokens.dart';
import '../../settings/data/settings_providers.dart';
import '../../settings/domain/app_settings.dart';
import '../../templates/data/template_providers.dart';
import '../../templates/domain/template.dart';
import '../data/plan_providers.dart';
import '../domain/plan_schedule.dart';
import 'plan_labels.dart';
import 'plan_sheets.dart';

/// Edytor planu tygodnia (ADR 0015): szablony w dniach tygodnia. Zapis
/// obowiązuje od dziś; przeszłe dni zostają bez zmian.
class WeeklyPlanScreen extends ConsumerStatefulWidget {
  const WeeklyPlanScreen({super.key});

  @override
  ConsumerState<WeeklyPlanScreen> createState() => _WeeklyPlanScreenState();
}

class _WeeklyPlanScreenState extends ConsumerState<WeeklyPlanScreen> {
  Map<int, List<String>>? _days;
  bool _dirty = false;

  LocalDate _today() {
    final now = ref.read(clockProvider).nowUtc().toLocal();
    return LocalDate(now.year, now.month, now.day);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toString();
    final plan = ref.watch(planProvider).value;
    final templates = ref.watch(templatesProvider).value;
    final settings =
        ref.watch(appSettingsProvider).value ?? const AppSettings();
    if (plan == null || templates == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.planWeekEditorTitle)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final byId = {for (final t in templates) t.id: t};
    final days = _days ??= {
      for (final MapEntry(:key, :value) in weeklyTemplates(
        currentWeeklyPlan(plan.weekly, _today()),
      ).entries)
        key: [...value],
    };
    String preview(AppLocalizations l10n, Template t) {
      final p = templatePreview(
        t,
        defaultRestSeconds: settings.defaultRestSeconds,
      );
      return l10n.planPreviewLine(p.exercises, p.sets, p.minutes);
    }

    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_confirmDiscard());
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.planWeekEditorTitle),
          actions: [
            TextButton(
              onPressed: _dirty ? () => unawaited(_save()) : null,
              child: Text(l10n.commonSave),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.gutter,
            AppSpacing.s,
            AppSpacing.gutter,
            AppSpacing.xl,
          ),
          children: [
            Text(
              l10n.planWeekEditorInfo,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.m),
            for (var weekday = 1; weekday <= 7; weekday++)
              Card(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.l,
                    AppSpacing.m,
                    AppSpacing.xs,
                    AppSpacing.xs,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Semantics(
                        header: true,
                        child: Text(
                          weekdayName(weekday, locale),
                          style: theme.textTheme.titleSmall,
                        ),
                      ),
                      if (days[weekday]!.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: AppSpacing.xs),
                          child: Text(
                            l10n.planRestDay,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      for (final (index, id) in days[weekday]!.indexed)
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                byId[id]?.name ?? l10n.planDeletedTemplate,
                                style: theme.textTheme.bodyLarge,
                              ),
                            ),
                            IconButton(
                              tooltip: l10n.planRemoveFromDay(
                                byId[id]?.name ?? l10n.planDeletedTemplate,
                              ),
                              icon: const Icon(Icons.close_rounded),
                              onPressed: () => setState(() {
                                days[weekday]!.removeAt(index);
                                _dirty = true;
                              }),
                            ),
                          ],
                        ),
                      TextButton.icon(
                        icon: const Icon(Icons.add_rounded),
                        label: Text(l10n.planAddWorkout),
                        onPressed: () async {
                          final picked = await pickTemplate(
                            context,
                            templates: [
                              for (final t in templates)
                                if (!t.isArchived) t,
                            ],
                            preview: preview,
                          );
                          if (picked == null) return;
                          setState(() {
                            days[weekday]!.add(picked.id);
                            _dirty = true;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: AppSpacing.l),
            _RemindersCard(settings: settings),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final plan = ref.read(planProvider).value!;
    final edit = editWeeklyPlan(
      plans: plan.weekly,
      days: _days!,
      today: _today(),
      ids: ref.read(idGeneratorProvider),
    );
    await ref
        .read(planRepositoryProvider)
        .saveWeekly(save: edit.save, delete: edit.delete);
    if (!mounted) return;
    setState(() => _dirty = false);
    messenger.showSnackBar(SnackBar(content: Text(l10n.planWeekSaved)));
    navigator.pop();
  }

  Future<void> _confirmDiscard() async {
    final l10n = AppLocalizations.of(context);
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.planDiscardTitle),
        content: Text(l10n.planDiscardBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.planDiscard),
          ),
        ],
      ),
    );
    if (discard == true && mounted) {
      setState(() => _dirty = false);
      Navigator.of(context).pop();
    }
  }
}

/// Przypomnienia o treningach z planu: zapisywane od razu, jak inne
/// ustawienia.
class _RemindersCard extends ConsumerWidget {
  const _RemindersCard({required this.settings});

  final AppSettings settings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final minutes = settings.planReminderMinutes;
    final time = TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60);
    final formatted = MaterialLocalizations.of(context)
        .formatTimeOfDay(time, alwaysUse24HourFormat: true);
    Future<void> save(AppSettings next) =>
        ref.read(settingsRepositoryProvider).save(next);
    return Card(
      child: Column(
        children: [
          SwitchListTile(
            title: Text(l10n.planReminders),
            subtitle: Text(
              settings.planReminders
                  ? l10n.planRemindersOn(formatted)
                  : l10n.planRemindersOff,
            ),
            value: settings.planReminders,
            onChanged: (on) async {
              final messenger = ScaffoldMessenger.of(context);
              if (on &&
                  !await ref.read(planRemindersProvider).requestPermission()) {
                messenger.showSnackBar(
                  SnackBar(content: Text(l10n.planRemindersDenied)),
                );
                return;
              }
              await save(settings.copyWith(planReminders: on));
            },
          ),
          ListTile(
            enabled: settings.planReminders,
            title: Text(l10n.planReminderTime),
            trailing: Text(
              formatted,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: settings.planReminders
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            onTap: () async {
              final picked = await showTimePicker(
                context: context,
                initialTime: time,
              );
              if (picked == null) return;
              await save(
                settings.copyWith(
                  planReminderMinutes: picked.hour * 60 + picked.minute,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
