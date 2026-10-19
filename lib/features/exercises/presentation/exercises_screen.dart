import 'package:flutter/material.dart';

import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/widgets/empty_state.dart';

/// Biblioteka ćwiczeń. Implementacja w Etapie 2.
class ExercisesScreen extends StatelessWidget {
  const ExercisesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.navExercises)),
      body: EmptyState(
        icon: Icons.fitness_center_rounded,
        title: l10n.comingSoonTitle,
        message: l10n.exercisesPlaceholder,
      ),
    );
  }
}
