import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/database/database_providers.dart';
import '../../../core/l10n/formatters.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/ticker_builder.dart';
import '../data/workout_providers.dart';

/// Pasek „Trening trwa · 32:10 · Wróć” nad dolną nawigacją, widoczny na
/// każdym ekranie shella, gdy trwa trening (docs/ux.md).
class ActiveWorkoutBar extends ConsumerWidget {
  const ActiveWorkoutBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(activeSessionProvider).value;
    if (session == null) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = context.appColors;
    final style = theme.textTheme.titleSmall?.copyWith(
      color: colors.onAccentFill,
      fontFeatures: AppTheme.tabularFigures,
    );

    return Material(
      color: colors.accentFill,
      child: InkWell(
        onTap: () => context.push(AppRoutes.workout),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppSizes.minTouch + 4),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
            child: Row(
              children: [
                Icon(Icons.timer_outlined, color: colors.onAccentFill),
                const SizedBox(width: AppSpacing.m),
                Expanded(
                  child: TickerBuilder(
                    builder: (context) {
                      final now = ref.read(clockProvider).nowUtc();
                      final seconds = max(
                        0,
                        now.difference(session.startedAt).inSeconds,
                      );
                      return Text(
                        l10n.workoutActiveBar(formatClock(seconds)),
                        style: style,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      );
                    },
                  ),
                ),
                Text(
                  l10n.workoutResume,
                  style: style?.copyWith(fontWeight: FontWeight.w700),
                ),
                Icon(Icons.chevron_right_rounded, color: colors.onAccentFill),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
