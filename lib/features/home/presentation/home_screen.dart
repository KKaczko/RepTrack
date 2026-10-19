import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/routes.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/active_workout_dialog.dart';
import '../../workout/data/workout_providers.dart';
import '../../workout/domain/workout_session.dart';

/// Ekran Start: wznowienie trwającego treningu albo pusty trening. Szybki
/// start ostatniego szablonu, ostatnia sesja i treningi w tygodniu dochodzą
/// w Etapie 5.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final active = ref.watch(activeSessionProvider).value;
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
          else
            SizedBox(
              height: AppSizes.stepper,
              child: OutlinedButton.icon(
                onPressed: () => _startEmpty(context, ref),
                icon: const Icon(Icons.add_rounded),
                label: Text(l10n.startEmptyWorkout),
              ),
            ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            l10n.homePlaceholder,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _startEmpty(BuildContext context, WidgetRef ref) async {
    final started = await ref.read(workoutStarterProvider).startEmpty();
    if (!context.mounted) return;
    if (started || await showActiveWorkoutDialog(context)) {
      if (context.mounted) await context.push(AppRoutes.workout);
    }
  }
}

class _ResumeCard extends StatelessWidget {
  const _ResumeCard({required this.session});

  final WorkoutSession session;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toString();
    final started = DateFormat.Hm(locale).format(session.startedAt.toLocal());
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
