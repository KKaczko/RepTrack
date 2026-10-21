import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/domain/glossary.dart';
import '../../../core/domain/training.dart';
import '../../../core/domain/units.dart';
import '../../../core/l10n/formatters.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/platform/rest_notifications.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/term_info.dart';
import '../data/settings_providers.dart';
import '../domain/app_settings.dart';
import 'assistant_settings_section.dart';

/// Ustawienia (ADR 0010): trening, wygląd i informacje o aplikacji. Każda
/// zmiana zapisuje się od razu.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late Future<bool> _exactAlarms;
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _exactAlarms = _checkExactAlarms();
    // Po powrocie z ustawień systemu odświeżamy status zgody.
    _lifecycle = AppLifecycleListener(
      onResume: () => setState(() => _exactAlarms = _checkExactAlarms()),
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  Future<bool> _checkExactAlarms() async {
    try {
      return await ref.read(restNotificationsProvider).exactAlarmsAllowed();
    } on Object {
      return false;
    }
  }

  Future<void> _save(AppSettings settings) =>
      ref.read(settingsRepositoryProvider).save(settings);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final settings =
        ref.watch(appSettingsProvider).value ?? const AppSettings();
    final locale = Localizations.localeOf(context).toString();
    final unit = settings.weightUnit;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: ListView(
        padding: const EdgeInsets.only(bottom: AppSpacing.xl),
        children: [
          _Section(l10n.settingsWorkout),
          _SegmentedTile<WeightUnit>(
            title: l10n.settingsWeightUnit,
            value: unit,
            options: {for (final u in WeightUnit.values) u: weightUnitLabel(u)},
            onChanged: (u) => _save(withWeightUnit(settings, u)),
          ),
          ListTile(
            title: Text(l10n.settingsWeightStep),
            trailing: _Value(
              '${formatDecimal(settings.weightStep, locale)} '
              '${weightUnitLabel(unit)}',
            ),
            onTap: () async {
              final step = await _choose<double>(
                title: l10n.settingsWeightStep,
                current: settings.weightStep,
                options: {
                  for (final s in weightStepOptions(unit))
                    s: '${formatDecimal(s, locale)} ${weightUnitLabel(unit)}',
                },
              );
              if (step != null) {
                await _save(settings.copyWith(weightStep: step));
              }
            },
          ),
          ListTile(
            title: Text(l10n.settingsDurationStep),
            trailing: _Value(
              l10n.settingsSeconds(settings.durationStepSeconds),
            ),
            onTap: () async {
              final step = await _choose<int>(
                title: l10n.settingsDurationStep,
                current: settings.durationStepSeconds,
                options: {
                  for (final s in durationStepOptions)
                    s: l10n.settingsSeconds(s),
                },
              );
              if (step != null) {
                await _save(settings.copyWith(durationStepSeconds: step));
              }
            },
          ),
          ListTile(
            title: Text(l10n.settingsDistanceStep),
            trailing: _Value(l10n.settingsMeters(settings.distanceStepMeters)),
            onTap: () async {
              final step = await _choose<int>(
                title: l10n.settingsDistanceStep,
                current: settings.distanceStepMeters,
                options: {
                  for (final m in distanceStepOptions)
                    m: l10n.settingsMeters(m),
                },
              );
              if (step != null) {
                await _save(settings.copyWith(distanceStepMeters: step));
              }
            },
          ),
          _SegmentedTile<EffortScale?>(
            title: l10n.settingsEffortScale,
            info: const [GlossaryTerm.rir, GlossaryTerm.rpe],
            value: settings.effortScale,
            options: {
              null: l10n.effortOff,
              EffortScale.rir: l10n.effortRir,
              EffortScale.rpe: l10n.effortRpe,
            },
            onChanged: (scale) => _save(settings.copyWith(effortScale: scale)),
          ),
          ListTile(
            title: Text(l10n.settingsDefaultRest),
            trailing: _Value(formatClock(settings.defaultRestSeconds)),
            onTap: () async {
              final seconds = await _choose<int>(
                title: l10n.settingsDefaultRest,
                current: settings.defaultRestSeconds,
                options: {
                  for (final s in {
                    ...restChoicesSeconds,
                    settings.defaultRestSeconds,
                  }.toList()..sort())
                    s: formatClock(s),
                },
              );
              if (seconds != null) {
                await _save(settings.copyWith(defaultRestSeconds: seconds));
              }
            },
          ),
          SwitchListTile(
            title: Text(l10n.settingsKeepScreenOn),
            value: settings.keepScreenOn,
            onChanged: (value) => _save(settings.copyWith(keepScreenOn: value)),
          ),
          FutureBuilder<bool>(
            future: _exactAlarms,
            builder: (context, snapshot) {
              final allowed = snapshot.data ?? true;
              return ListTile(
                title: Text(l10n.settingsExactAlarm),
                subtitle: Text(
                  allowed
                      ? l10n.settingsExactAlarmOn
                      : l10n.settingsExactAlarmOff,
                ),
                trailing: Icon(
                  allowed
                      ? Icons.check_circle_rounded
                      : Icons.warning_amber_rounded,
                ),
                onTap: allowed
                    ? null
                    : () => unawaited(
                        ref
                            .read(restNotificationsProvider)
                            .requestExactAlarms(),
                      ),
              );
            },
          ),
          _Section(l10n.settingsAppearance),
          _SegmentedTile<AppThemeMode>(
            title: l10n.settingsTheme,
            value: settings.themeMode,
            options: {
              AppThemeMode.dark: l10n.themeDark,
              AppThemeMode.light: l10n.themeLight,
              AppThemeMode.system: l10n.themeSystem,
            },
            onChanged: (mode) => _save(settings.copyWith(themeMode: mode)),
          ),
          _Section(l10n.settingsAssistant),
          AssistantSettingsSection(settings: settings),
          _Section(l10n.settingsData),
          ListTile(
            leading: const Icon(Icons.backup_outlined),
            title: Text(l10n.backupTitle),
            subtitle: Text(l10n.settingsBackupSubtitle),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => context.push(AppRoutes.backup),
          ),
          _Section(l10n.settingsHelp),
          ListTile(
            leading: const Icon(Icons.menu_book_rounded),
            title: Text(l10n.glossaryOpen),
            subtitle: Text(l10n.glossaryOpenSubtitle),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => context.push(AppRoutes.glossary),
          ),
          _Section(l10n.settingsAbout),
          ListTile(
            leading: const Icon(Icons.gavel_rounded),
            title: Text(l10n.settingsLicenses),
            subtitle: Text(l10n.settingsLicensesSubtitle),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => context.push(AppRoutes.licenses),
          ),
        ],
      ),
    );
  }

  Future<T?> _choose<T>({
    required String title,
    required T current,
    required Map<T, String> options,
  }) => showDialog<T>(
    context: context,
    builder: (context) => SimpleDialog(
      title: Text(title),
      children: [
        for (final MapEntry(key: value, value: label) in options.entries)
          SimpleDialogOption(
            onPressed: () => Navigator.of(context).pop(value),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: AppSizes.minTouch),
              child: Row(
                children: [
                  Expanded(child: Text(label)),
                  if (value == current) const Icon(Icons.check_rounded),
                ],
              ),
            ),
          ),
      ],
    ),
  );
}

/// Bieżąca wartość ustawienia otwieranego w oknie wyboru.
class _Value extends StatelessWidget {
  const _Value(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      text,
      style: theme.textTheme.bodyLarge?.copyWith(
        color: theme.colorScheme.primary,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.gutter,
        AppSpacing.l,
        AppSpacing.gutter,
        AppSpacing.s,
      ),
      child: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }
}

/// Ustawienie z kilkoma wartościami pokazanymi naraz.
class _SegmentedTile<T> extends StatelessWidget {
  const _SegmentedTile({
    required this.title,
    required this.value,
    required this.options,
    required this.onChanged,
    this.info,
  });

  final String title;
  final T value;
  final Map<T, String> options;
  final ValueChanged<T> onChanged;

  /// Pojęcia z ikonką ⓘ przy tytule.
  final List<GlossaryTerm>? info;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      AppSpacing.gutter,
      AppSpacing.s,
      AppSpacing.gutter,
      AppSpacing.s,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (info case final terms?)
          TermTitle(
            title,
            terms: terms,
            style: Theme.of(context).textTheme.bodyLarge,
          )
        else
          Text(title, style: Theme.of(context).textTheme.bodyLarge),
        const SizedBox(height: AppSpacing.s),
        SegmentedButton<T>(
          showSelectedIcon: false,
          segments: [
            for (final MapEntry(key: option, value: label) in options.entries)
              ButtonSegment(value: option, label: Text(label)),
          ],
          selected: {value},
          onSelectionChanged: (selection) => onChanged(selection.single),
        ),
      ],
    ),
  );
}
