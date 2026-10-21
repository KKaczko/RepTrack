import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../core/domain/coded_enum.dart';
import '../../../core/domain/training.dart';
import '../../../core/domain/units.dart';
import '../../exercises/domain/exercise.dart';

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

    /// Kroki ciężaru dla sprzętu (np. hantle co 2 kg); brak wpisu oznacza
    /// krok ogólny [weightStep] (ADR 0020).
    @Default(<Equipment, double>{}) Map<Equipment, double> equipmentWeightSteps,

    /// Waga gryfu dla sztangi i gryfu łamanego w jednostce wyświetlania;
    /// brak wpisu oznacza wartość domyślną (ADR 0020).
    @Default(<Equipment, double>{}) Map<Equipment, double> barWeights,

    /// Dostępne talerze w jednostce wyświetlania; null oznacza zestaw
    /// domyślny dla jednostki.
    List<double>? plates,

    /// Krok stepperów czasu (sekundy) i dystansu (metry) w treningu.
    @Default(5) int durationStepSeconds,
    @Default(100) int distanceStepMeters,

    /// Skala wysiłku; null oznacza, że pole wysiłku jest wyłączone.
    @Default(EffortScale.rir) EffortScale? effortScale,
    @Default(120) int defaultRestSeconds,
    @Default(true) bool keepScreenOn,

    /// Progresja podwójna w podpowiedziach treningu (ADR 0017).
    @Default(true) bool autoProgression,

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

/// Sprzęt z własnym krokiem ciężaru w ustawieniach; sztanga używa kroku
/// ogólnego.
const equipmentWithOwnStep = [
  Equipment.dumbbell,
  Equipment.kettlebell,
  Equipment.machine,
  Equipment.cable,
  Equipment.smithMachine,
  Equipment.ezBar,
];

/// Kroki ciężaru dla sprzętu: lista ogólna plus typowe skoki hantli (2 kg)
/// i kettlebell (4 kg).
List<double> equipmentStepOptions(WeightUnit unit) => switch (unit) {
  WeightUnit.kg => const [0.5, 1, 1.25, 2, 2.5, 4, 5],
  WeightUnit.lb => const [1, 2.5, 5, 10],
};

/// Krok ciężaru dla ćwiczenia z [equipment]: własny krok sprzętu albo
/// ogólny (ADR 0020).
double weightStepFor(Equipment? equipment, AppSettings settings) =>
    (equipment == null ? null : settings.equipmentWeightSteps[equipment]) ??
    settings.weightStep;

/// Zmiana jednostki. Krok spoza listy nowej jednostki wraca do domyślnego,
/// bo np. 1,25 lb nie odpowiada żadnemu talerzowi. Kroki dla sprzętu
/// wracają do ogólnego.
AppSettings withWeightUnit(AppSettings settings, WeightUnit unit) =>
    settings.copyWith(
      weightUnit: unit,
      weightStep: weightStepOptions(unit).contains(settings.weightStep)
          ? settings.weightStep
          : defaultWeightStep(unit),
      equipmentWeightSteps: const {},
      barWeights: const {},
      plates: null,
    );

/// Sprzęt z kalkulatorem talerzy.
const equipmentWithPlates = [Equipment.barbell, Equipment.ezBar];

/// Domyślna waga gryfu: sztanga 20 kg / 45 lb, gryf łamany 10 kg / 20 lb.
double defaultBarWeight(Equipment equipment, WeightUnit unit) =>
    switch ((equipment, unit)) {
      (Equipment.ezBar, WeightUnit.kg) => 10,
      (Equipment.ezBar, WeightUnit.lb) => 20,
      (_, WeightUnit.kg) => 20,
      (_, WeightUnit.lb) => 45,
    };

/// Wagi gryfu do wyboru w danej jednostce.
List<double> barWeightOptions(WeightUnit unit) => switch (unit) {
  WeightUnit.kg => const [5, 7.5, 10, 15, 20],
  WeightUnit.lb => const [15, 20, 25, 35, 45],
};

/// Talerze do wyboru (nominały) w danej jednostce.
List<double> plateOptions(WeightUnit unit) => switch (unit) {
  WeightUnit.kg => const [25, 20, 15, 10, 5, 2.5, 2, 1.25, 1, 0.5],
  WeightUnit.lb => const [55, 45, 35, 25, 10, 5, 2.5, 1.25],
};

/// Domyślny zestaw talerzy na siłowni.
List<double> defaultPlates(WeightUnit unit) => switch (unit) {
  WeightUnit.kg => const [25, 20, 15, 10, 5, 2.5, 1.25],
  WeightUnit.lb => const [45, 35, 25, 10, 5, 2.5],
};

double barWeightFor(Equipment equipment, AppSettings settings) =>
    settings.barWeights[equipment] ??
    defaultBarWeight(equipment, settings.weightUnit);

List<double> platesFor(AppSettings settings) =>
    settings.plates ?? defaultPlates(settings.weightUnit);
