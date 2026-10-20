import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/routes.dart';
import '../../../core/database/database_providers.dart';
import '../../../core/domain/local_date.dart';
import '../../../core/domain/units.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/platform/file_exchange.dart';
import '../../../core/platform/rest_notifications.dart';
import '../../../core/theme/tokens.dart';
import '../../exercises/data/exercise_providers.dart';
import '../../settings/data/settings_providers.dart';
import '../../workout/data/workout_providers.dart';
import '../data/backup_providers.dart';
import '../data/backup_service.dart';
import '../domain/backup_validation.dart';
import '../domain/workout_export.dart';
import 'export_labels.dart';

enum _Period { all, days30, days90, year, custom }

enum _Format { csv, markdown }

/// Kopia zapasowa i eksport treningów (spec. 6). Kopia zawsze obejmuje
/// wszystko; filtry okresu i ćwiczeń dotyczą tylko eksportu CSV i Markdown.
class BackupScreen extends ConsumerStatefulWidget {
  const BackupScreen({super.key});

  @override
  ConsumerState<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends ConsumerState<BackupScreen> {
  final _messenger = GlobalKey<ScaffoldMessengerState>();
  bool _busy = false;
  _Period _period = _Period.all;
  DateTimeRange? _custom;
  Set<String>? _exerciseIds;
  _Format _format = _Format.csv;
  MarkdownLayout _layout = MarkdownLayout.perSession;

  FileExchange get _files => ref.read(fileExchangeProvider);

  void _snack(String text) => _messenger.currentState
    ?..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));

  /// Wykonuje operację na pliku z blokadą przycisków i komunikatem błędu.
  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } on PlatformException {
      if (mounted) _snack(AppLocalizations.of(context).backupFailedSnack);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final history = ref.watch(completedSessionsProvider).value ?? const [];
    final rows = exportRows(history, _filter());
    final workouts = {for (final r in rows) r.session.id}.length;
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    return ScaffoldMessenger(
      key: _messenger,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.backupTitle),
          bottom: _busy
              ? const PreferredSize(
                  preferredSize: Size.fromHeight(4),
                  child: LinearProgressIndicator(),
                )
              : null,
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.gutter,
            AppSpacing.s,
            AppSpacing.gutter,
            AppSpacing.xxl,
          ),
          children: [
            _Title(l10n.backupSection),
            Text(l10n.backupDescription, style: muted),
            const SizedBox(height: AppSpacing.m),
            _Action(
              filled: true,
              icon: Icons.save_alt_rounded,
              label: l10n.backupSave,
              onPressed: _busy ? null : () => _run(_saveBackup),
            ),
            _Action(
              icon: Icons.share_outlined,
              label: l10n.backupShare,
              onPressed: _busy ? null : () => _run(_shareBackup),
            ),
            _Action(
              icon: Icons.settings_backup_restore_rounded,
              label: l10n.backupRestore,
              onPressed: _busy ? null : _restore,
            ),
            const SizedBox(height: AppSpacing.l),
            _Title(l10n.exportSection),
            Text(l10n.exportDescription, style: muted),
            const SizedBox(height: AppSpacing.m),
            Text(l10n.exportPeriod, style: theme.textTheme.titleSmall),
            const SizedBox(height: AppSpacing.s),
            Wrap(
              spacing: AppSpacing.s,
              runSpacing: AppSpacing.s,
              children: [
                for (final period in _Period.values)
                  ChoiceChip(
                    label: Text(_periodLabel(l10n, period)),
                    selected: _period == period,
                    onSelected: (_) => _selectPeriod(period),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.l),
            Text(l10n.exportExercises, style: theme.textTheme.titleSmall),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                _exerciseIds == null
                    ? l10n.exportExercisesAll
                    : l10n.exercisesCount(_exerciseIds!.length),
              ),
              trailing: _exerciseIds == null
                  ? const Icon(Icons.chevron_right_rounded)
                  : TextButton(
                      onPressed: () => setState(() => _exerciseIds = null),
                      child: Text(l10n.exportExercisesReset),
                    ),
              onTap: _pickExercises,
            ),
            Text(l10n.exportFormat, style: theme.textTheme.titleSmall),
            const SizedBox(height: AppSpacing.s),
            SegmentedButton<_Format>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: _Format.csv, label: Text('CSV')),
                ButtonSegment(value: _Format.markdown, label: Text('Markdown')),
              ],
              selected: {_format},
              onSelectionChanged: (s) => setState(() => _format = s.single),
            ),
            if (_format == _Format.markdown) ...[
              const SizedBox(height: AppSpacing.m),
              Text(l10n.exportLayout, style: theme.textTheme.titleSmall),
              const SizedBox(height: AppSpacing.s),
              SegmentedButton<MarkdownLayout>(
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(
                    value: MarkdownLayout.perSession,
                    label: Text(l10n.exportLayoutSessions),
                  ),
                  ButtonSegment(
                    value: MarkdownLayout.perExercise,
                    label: Text(l10n.exportLayoutExercises),
                  ),
                ],
                selected: {_layout},
                onSelectionChanged: (s) => setState(() => _layout = s.single),
              ),
            ],
            const SizedBox(height: AppSpacing.m),
            Text(
              rows.isEmpty
                  ? l10n.exportEmpty
                  : l10n.exportCount(rows.length, workouts),
              style: muted,
            ),
            const SizedBox(height: AppSpacing.m),
            Wrap(
              spacing: AppSpacing.s,
              runSpacing: AppSpacing.s,
              children: [
                FilledButton.icon(
                  onPressed: _busy || rows.isEmpty
                      ? null
                      : () => _run(() => _shareExport(rows)),
                  icon: const Icon(Icons.share_outlined),
                  label: Text(l10n.exportShare),
                ),
                OutlinedButton.icon(
                  onPressed: _busy || rows.isEmpty
                      ? null
                      : () => _run(() => _saveExport(rows)),
                  icon: const Icon(Icons.save_alt_rounded),
                  label: Text(l10n.exportSave),
                ),
                if (_format == _Format.markdown)
                  OutlinedButton.icon(
                    onPressed: _busy || rows.isEmpty
                        ? null
                        : () => _run(() => _copyExport(rows)),
                    icon: const Icon(Icons.copy_rounded),
                    label: Text(l10n.exportCopy),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _periodLabel(AppLocalizations l10n, _Period period) {
    final range = _custom;
    if (period == _Period.custom && range != null) {
      final locale = Localizations.localeOf(context).toString();
      final format = DateFormat.Md(locale);
      return '${format.format(range.start)}–${format.format(range.end)}';
    }
    return switch (period) {
      _Period.all => l10n.exportPeriodAll,
      _Period.days30 => l10n.exportPeriod30,
      _Period.days90 => l10n.exportPeriod90,
      _Period.year => l10n.exportPeriodYear,
      _Period.custom => l10n.exportPeriodCustom,
    };
  }

  LocalDate _today() {
    final now = ref.read(clockProvider).nowUtc().toLocal();
    return LocalDate(now.year, now.month, now.day);
  }

  ExportFilter _filter() {
    final today = _today();
    LocalDate local(DateTime d) => LocalDate(d.year, d.month, d.day);
    final (from, to) = switch (_period) {
      _Period.all => (null, null),
      _Period.days30 => (today.addDays(-29), today),
      _Period.days90 => (today.addDays(-89), today),
      _Period.year => (today.addDays(-364), today),
      _Period.custom => (
        _custom == null ? null : local(_custom!.start),
        _custom == null ? null : local(_custom!.end),
      ),
    };
    return ExportFilter(from: from, to: to, exerciseIds: _exerciseIds);
  }

  Future<void> _selectPeriod(_Period period) async {
    if (period != _Period.custom) {
      setState(() => _period = period);
      return;
    }
    final now = ref.read(clockProvider).nowUtc().toLocal();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year, now.month, now.day),
      initialDateRange: _custom,
    );
    if (range == null) return;
    setState(() {
      _custom = range;
      _period = _Period.custom;
    });
  }

  Future<void> _pickExercises() async {
    final ids = await context.push<List<String>>(AppRoutes.exercisePicker);
    if (ids == null || ids.isEmpty) return;
    setState(() => _exerciseIds = ids.toSet());
  }

  /// Treść eksportu w wybranym formacie z nazwą pliku i typem MIME.
  ({String content, String fileName, String mimeType}) _export(
    List<ExportRow> rows,
  ) {
    final l10n = AppLocalizations.of(context);
    final unit =
        ref.read(appSettingsProvider).value?.weightUnit ?? WeightUnit.kg;
    final names = {
      for (final e in (ref.read(exercisesByIdProvider).value ?? {}).values)
        e.id: e.name,
    };
    final labels = exportLabels(l10n, unit);
    final stamp = _today().toIso();
    return switch (_format) {
      _Format.csv => (
        content: exportCsv(
          rows,
          labels: labels,
          unit: unit,
          exerciseNames: names,
        ),
        fileName: 'reptrack-treningi-$stamp.csv',
        mimeType: 'text/csv',
      ),
      _Format.markdown => (
        content: exportMarkdown(
          rows,
          labels: labels,
          unit: unit,
          exerciseNames: names,
          layout: _layout,
        ),
        fileName: 'reptrack-treningi-$stamp.md',
        mimeType: 'text/markdown',
      ),
    };
  }

  Future<void> _shareExport(List<ExportRow> rows) async {
    final export = _export(rows);
    // Markdown jako tekst: od razu do wklejenia w czacie.
    if (_format == _Format.markdown) {
      await _files.shareText(export.content, subject: export.fileName);
    } else {
      await _files.shareFile(
        fileName: export.fileName,
        content: export.content,
        mimeType: export.mimeType,
      );
    }
  }

  Future<void> _saveExport(List<ExportRow> rows) async {
    final l10n = AppLocalizations.of(context);
    final export = _export(rows);
    final saved = await _files.save(
      fileName: export.fileName,
      content: export.content,
      mimeType: export.mimeType,
    );
    if (saved && mounted) _snack(l10n.exportSavedSnack);
  }

  Future<void> _copyExport(List<ExportRow> rows) async {
    final l10n = AppLocalizations.of(context);
    await Clipboard.setData(ClipboardData(text: _export(rows).content));
    if (mounted) _snack(l10n.exportCopiedSnack);
  }

  Future<void> _saveBackup() async {
    final l10n = AppLocalizations.of(context);
    final service = ref.read(backupServiceProvider);
    final saved = await _files.save(
      fileName: service.fileName(),
      content: await service.exportJson(),
      mimeType: 'application/json',
    );
    if (saved && mounted) _snack(l10n.backupSavedSnack);
  }

  Future<void> _shareBackup() async {
    final service = ref.read(backupServiceProvider);
    await _files.shareFile(
      fileName: service.fileName(),
      content: await service.exportJson(),
      mimeType: 'application/json',
    );
  }

  /// Przywracanie: okna potwierdzeń i błędów pokazują się poza blokadą
  /// [_run], która dotyczy tylko operacji na plikach i bazie.
  Future<void> _restore() async {
    final l10n = AppLocalizations.of(context);
    final service = ref.read(backupServiceProvider);
    String? text;
    var unreadable = false;
    await _run(() async {
      try {
        text = await _files.pickText();
      } on FormatException {
        unreadable = true;
      }
    });
    if (!mounted) return;
    if (unreadable) {
      return _showError(l10n.backupInvalidTitle, l10n.backupInvalidMessage);
    }
    final picked = text;
    if (picked == null) return;
    final PreparedRestore prepared;
    try {
      prepared = service.prepare(picked);
    } on BackupTooNewException catch (e) {
      return _showError(
        l10n.backupTooNewTitle,
        l10n.backupTooNewMessage(e.formatVersion),
      );
    } on BackupInvalidException catch (e) {
      return _showError(
        l10n.backupInvalidTitle,
        l10n.backupInvalidMessage,
        details: e.problems.take(3).join('\n'),
      );
    }
    if (!mounted) return;
    final summary = prepared.summary;
    final locale = Localizations.localeOf(context).toString();
    final hasActive =
        summary.hasActiveWorkout ||
        ref.read(activeSessionProvider).value != null;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.backupRestoreTitle),
        content: Text(
          [
            l10n.backupRestoreMessage(
              DateFormat.yMMMd(locale)
                  .add_Hm()
                  .format(summary.exportedAt.toLocal()),
              l10n.workoutsCount(summary.workouts),
              l10n.backupTemplatesCount(summary.templates),
              l10n.backupOwnExercisesCount(summary.ownExercises),
            ),
            if (hasActive) l10n.backupRestoreActiveWarning,
          ].join('\n\n'),
        ),
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
            child: Text(l10n.backupRestoreConfirm),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _run(() async {
      await service.restore(prepared);
      // Przerwa poprzedniego treningu nie dotyczy przywróconych danych.
      try {
        await ref.read(restNotificationsProvider).cancelRest();
      } on Object {
        // Brak powiadomień nie blokuje przywrócenia.
      }
      if (mounted) _snack(l10n.backupRestoredSnack);
    });
  }

  Future<void> _showError(String title, String message, {String? details}) {
    final l10n = AppLocalizations.of(context);
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(details == null ? message : '$message\n\n$details'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.commonOk),
          ),
        ],
      ),
    );
  }
}

class _Title extends StatelessWidget {
  const _Title(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.m, bottom: AppSpacing.s),
      child: Text(
        text,
        style: theme.textTheme.titleMedium?.copyWith(
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.filled = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool filled;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.s),
    child: SizedBox(
      height: AppSizes.stepper,
      child: filled
          ? FilledButton.icon(
              onPressed: onPressed,
              icon: Icon(icon),
              label: Text(label),
            )
          : OutlinedButton.icon(
              onPressed: onPressed,
              icon: Icon(icon),
              label: Text(label),
            ),
    ),
  );
}
