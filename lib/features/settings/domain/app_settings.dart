import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../core/domain/coded_enum.dart';
import '../../../core/domain/training.dart';
import '../../../core/domain/units.dart';

part 'app_settings.freezed.dart';

enum AppThemeMode implements CodedEnum {
  dark('dark'),
  light('light'),
  system('system');

  const AppThemeMode(this.code);

  @override
  final String code;
}

/// Ustawienia aplikacji (ADR 0010). Przechowywane w bazie, więc backup
/// obejmuje je automatycznie.
@freezed
abstract class AppSettings with _$AppSettings {
  const factory AppSettings({
    @Default(AppThemeMode.dark) AppThemeMode themeMode,
    @Default(WeightUnit.kg) WeightUnit weightUnit,

    /// Krok ciężaru w jednostce wyświetlania (2,5 kg albo np. 5 lb).
    @Default(2.5) double weightStep,

    /// Krok stepperów czasu (sekundy) i dystansu (metry) w treningu.
    @Default(5) int durationStepSeconds,
    @Default(100) int distanceStepMeters,

    /// Skala wysiłku; null oznacza, że pole wysiłku jest wyłączone.
    @Default(EffortScale.rir) EffortScale? effortScale,
    @Default(120) int defaultRestSeconds,
    @Default(true) bool keepScreenOn,

    /// Prośba o dokładne alarmy końca przerwy była już pokazana.
    @Default(false) bool exactAlarmPrompted,

    /// Adres serwera Ollama asystenta AI (ADR 0014); null wyłącza asystenta.
    String? assistantUrl,

    /// Model asystenta; null oznacza pierwszy model z serwera.
    String? assistantModel,

    /// Przypomnienia o treningach z planu (ADR 0015).
    @Default(false) bool planReminders,

    /// Godzina przypomnienia w minutach od północy (17:00).
    @Default(1020) int planReminderMinutes,
  }) = _AppSettings;
}

/// Kroki czasu (sekundy) i dystansu (metry) do wyboru.
const durationStepOptions = <int>[1, 5, 10, 15, 30, 60];
const distanceStepOptions = <int>[10, 25, 50, 100, 250, 500, 1000];

/// Kroki ciężaru do wyboru w danej jednostce.
List<double> weightStepOptions(WeightUnit unit) => switch (unit) {
  WeightUnit.kg => const [0.5, 1, 1.25, 2.5, 5],
  WeightUnit.lb => const [1, 2.5, 5, 10],
};

/// Domyślny krok ciężaru: 2,5 kg albo 5 lb (najmniejsze typowe talerze
/// parami).
double defaultWeightStep(WeightUnit unit) => switch (unit) {
  WeightUnit.kg => 2.5,
  WeightUnit.lb => 5,
};

/// Zmiana jednostki. Krok spoza listy nowej jednostki wraca do domyślnego,
/// bo np. 1,25 lb nie odpowiada żadnemu talerzowi.
AppSettings withWeightUnit(AppSettings settings, WeightUnit unit) =>
    settings.copyWith(
      weightUnit: unit,
      weightStep: weightStepOptions(unit).contains(settings.weightStep)
          ? settings.weightStep
          : defaultWeightStep(unit),
    );
