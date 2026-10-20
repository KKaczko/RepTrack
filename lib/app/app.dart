import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/l10n/generated/app_localizations.dart';
import '../core/theme/app_theme.dart';
import '../features/plan/data/plan_reminder_sync.dart';
import '../features/settings/data/settings_providers.dart';
import '../features/settings/domain/app_settings.dart';
import 'router.dart';

class RepTrackApp extends ConsumerWidget {
  const RepTrackApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Przypomnienia o treningach z planu nadążają za zmianami (ADR 0015).
    ref.watch(planReminderSyncProvider);
    final themeMode =
        ref.watch(appSettingsProvider).value?.themeMode ??
        const AppSettings().themeMode;
    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: switch (themeMode) {
        AppThemeMode.dark => ThemeMode.dark,
        AppThemeMode.light => ThemeMode.light,
        AppThemeMode.system => ThemeMode.system,
      },
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: ref.watch(routerProvider),
    );
  }
}
