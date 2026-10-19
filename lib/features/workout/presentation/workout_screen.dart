import 'package:flutter/material.dart';

import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/widgets/empty_state.dart';

/// Aktywny trening. Implementacja w Etapie 4.
class WorkoutScreen extends StatelessWidget {
  const WorkoutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.workoutTitle)),
      body: EmptyState(
        icon: Icons.timer_rounded,
        title: l10n.comingSoonTitle,
        message: l10n.workoutPlaceholder,
      ),
    );
  }
}
