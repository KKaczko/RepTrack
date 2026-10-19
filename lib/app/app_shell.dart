import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/l10n/generated/app_localizations.dart';
import '../features/workout/presentation/active_workout_bar.dart';

/// Kontener nawigatorów zakładek. Każda zakładka ma własny
/// [ScaffoldMessenger]: snackbary układają się w scaffoldzie ekranu (nad jego
/// FAB), a nie w scaffoldzie z dolną nawigacją, i nie dublują się między
/// zakładkami. Nieaktywne zakładki są ukryte jak w `indexedStack` go_routera.
Widget branchContainer(
  BuildContext context,
  StatefulNavigationShell shell,
  List<Widget> children,
) => Stack(
  children: [
    for (final (index, child) in children.indexed)
      Offstage(
        offstage: index != shell.currentIndex,
        child: TickerMode(
          enabled: index == shell.currentIndex,
          child: ScaffoldMessenger(child: child),
        ),
      ),
  ],
);

/// Rama z dolną nawigacją dla czterech zakładek. Nad nawigacją wisi pasek
/// trwającego treningu.
class AppShell extends StatelessWidget {
  const AppShell({required this.shell, super.key});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: shell,
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const ActiveWorkoutBar(),
          NavigationBar(
            selectedIndex: shell.currentIndex,
            onDestinationSelected: (index) => shell.goBranch(
              index,
              // Ponowny tap w aktywną zakładkę wraca do jej korzenia.
              initialLocation: index == shell.currentIndex,
            ),
            destinations: [
              NavigationDestination(
                icon: const Icon(Icons.home_outlined),
                selectedIcon: const Icon(Icons.home_rounded),
                label: l10n.navStart,
              ),
              NavigationDestination(
                icon: const Icon(Icons.list_alt_outlined),
                selectedIcon: const Icon(Icons.list_alt_rounded),
                label: l10n.navTemplates,
              ),
              NavigationDestination(
                icon: const Icon(Icons.history_outlined),
                selectedIcon: const Icon(Icons.history_rounded),
                label: l10n.navHistory,
              ),
              NavigationDestination(
                icon: const Icon(Icons.fitness_center_outlined),
                selectedIcon: const Icon(Icons.fitness_center_rounded),
                label: l10n.navExercises,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
