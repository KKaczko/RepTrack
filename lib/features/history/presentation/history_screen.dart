import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/domain/units.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/empty_state.dart';
import '../../settings/data/settings_providers.dart';
import '../../workout/data/workout_providers.dart';
import '../../workout/domain/workout_session.dart';
import 'history_labels.dart';
import 'progress_tab.dart';

/// Historia: lista zakończonych treningów i progres (spec. 5.4, 5.5).
class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.navHistory),
          bottom: TabBar(
            tabs: [
              Tab(text: l10n.historyTabSessions),
              Tab(text: l10n.historyTabProgress),
            ],
          ),
        ),
        body: const TabBarView(children: [_SessionList(), ProgressTab()]),
      ),
    );
  }
}

class _SessionList extends ConsumerWidget {
  const _SessionList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final history = ref.watch(completedSessionsProvider);
    return switch (history) {
      AsyncData(:final value) when value.isEmpty => EmptyState(
        icon: Icons.history_rounded,
        title: l10n.historyEmptyTitle,
        message: l10n.historyEmptyMessage,
      ),
      AsyncData(:final value) => _buildList(context, ref, value),
      AsyncError(:final error) => Center(child: Text('$error')),
      _ => const Center(child: CircularProgressIndicator()),
    };
  }

  Widget _buildList(
    BuildContext context,
    WidgetRef ref,
    List<WorkoutSession> sessions,
  ) {
    final locale = Localizations.localeOf(context).toString();
    final unit =
        ref.watch(appSettingsProvider).value?.weightUnit ?? WeightUnit.kg;
    // Nagłówek miesiąca przed pierwszą sesją każdego miesiąca.
    final items = <Object>[];
    for (final session in sessions) {
      final date = session.localDate;
      final previous = items.isEmpty ? null : items.last;
      if (previous is! WorkoutSession ||
          previous.localDate.year != date.year ||
          previous.localDate.month != date.month) {
        items.add(monthHeader(date, locale));
      }
      items.add(session);
    }
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      itemCount: items.length,
      itemBuilder: (context, index) => switch (items[index]) {
        final String header => _MonthHeader(header),
        final WorkoutSession session => _SessionTile(
          session: session,
          unit: unit,
          locale: locale,
        ),
        _ => const SizedBox.shrink(),
      },
    );
  }
}

class _MonthHeader extends StatelessWidget {
  const _MonthHeader(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.gutter,
        AppSpacing.l,
        AppSpacing.gutter,
        AppSpacing.xs,
      ),
      child: Text(
        text,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }
}

class _SessionTile extends StatelessWidget {
  const _SessionTile({
    required this.session,
    required this.unit,
    required this.locale,
  });

  final WorkoutSession session;
  final WeightUnit unit;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
      title: Text(session.title ?? l10n.workoutTitle),
      subtitle: Text(
        '${l10n.sessionWhen(session, locale)}\n'
        '${l10n.sessionSummary(session, unit, locale)}',
      ),
      isThreeLine: true,
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: () => context.push(AppRoutes.sessionDetail(session.id)),
    );
  }
}
