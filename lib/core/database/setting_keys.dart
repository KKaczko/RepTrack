/// Klucze tabeli `settings` (docs/data-model.md). Stabilne: trafiają do backupu.
abstract final class SettingKeys {
  static const themeMode = 'theme_mode';
  static const weightUnit = 'weight_unit';
  static const weightStep = 'weight_step';

  /// Kroki ciężaru dla sprzętu: obiekt kod sprzętu → krok (ADR 0020).
  static const equipmentWeightSteps = 'equipment_weight_steps';
  static const durationStepSeconds = 'duration_step_seconds';
  static const distanceStepMeters = 'distance_step_meters';
  static const effortScale = 'effort_scale';
  static const defaultRestSeconds = 'default_rest_seconds';
  static const keepScreenOn = 'keep_screen_on';

  /// Progresja podwójna w podpowiedziach (ADR 0017).
  static const autoProgression = 'auto_progression';

  /// Czy pokazano już prośbę o dokładne alarmy końca przerwy (ADR 0009).
  static const exactAlarmPrompted = 'exact_alarm_prompted';

  /// Adres serwera Ollama i model asystenta AI (ADR 0014).
  static const assistantUrl = 'assistant_url';
  static const assistantModel = 'assistant_model';

  /// Przypomnienia o treningach z planu i ich godzina (ADR 0015).
  static const planReminders = 'plan_reminders';
  static const planReminderMinutes = 'plan_reminder_minutes';

  /// Wersja ostatnio zastosowanego seeda biblioteki ćwiczeń (wewnętrzne).
  static const seedVersion = 'seed_version';
}
