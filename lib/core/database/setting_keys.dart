/// Klucze tabeli `settings` (docs/data-model.md). Stabilne: trafiają do backupu.
abstract final class SettingKeys {
  static const themeMode = 'theme_mode';
  static const weightUnit = 'weight_unit';
  static const weightStep = 'weight_step';
  static const effortScale = 'effort_scale';
  static const defaultRestSeconds = 'default_rest_seconds';
  static const keepScreenOn = 'keep_screen_on';

  /// Wersja ostatnio zastosowanego seeda biblioteki ćwiczeń (wewnętrzne).
  static const seedVersion = 'seed_version';
}
