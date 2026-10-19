import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../core/domain/training.dart';
import '../../../core/domain/units.dart';

part 'app_settings.freezed.dart';

enum AppThemeMode { dark, light, system }

/// Ustawienia aplikacji (ADR 0010). Przechowywane w bazie, więc backup
/// obejmuje je automatycznie.
@freezed
abstract class AppSettings with _$AppSettings {
  const factory AppSettings({
    @Default(AppThemeMode.dark) AppThemeMode themeMode,
    @Default(WeightUnit.kg) WeightUnit weightUnit,

    /// Krok ciężaru w jednostce wyświetlania (2,5 kg albo np. 5 lb).
    @Default(2.5) double weightStep,

    /// Skala wysiłku; null oznacza, że pole wysiłku jest wyłączone.
    @Default(EffortScale.rir) EffortScale? effortScale,
    @Default(120) int defaultRestSeconds,
    @Default(true) bool keepScreenOn,
  }) = _AppSettings;
}
