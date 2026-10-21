import 'dart:convert';

import '../../../core/database/app_database.dart';
import '../../../core/database/setting_keys.dart';
import '../../../core/domain/clock.dart';
import '../../../core/domain/coded_enum.dart';
import '../../../core/domain/training.dart';
import '../../../core/domain/units.dart';
import '../../exercises/domain/exercise.dart';
import '../domain/app_settings.dart';
import '../domain/settings_repository.dart';

final class DriftSettingsRepository implements SettingsRepository {
  DriftSettingsRepository(this._db, this._clock);

  final AppDatabase _db;
  final Clock _clock;

  @override
  Stream<AppSettings> watch() =>
      _db.select(_db.settings).watch().map(_fromRows);

  @override
  Future<AppSettings> load() async =>
      _fromRows(await _db.select(_db.settings).get());

  @override
  Future<void> save(AppSettings settings) => _db.transaction(() async {
    final current = {
      for (final row in await _db.select(_db.settings).get())
        row.key: row.value,
    };
    final now = _clock.nowUtc();
    for (final MapEntry(:key, :value) in _toMap(settings).entries) {
      final encoded = jsonEncode(value);
      if (current[key] == encoded) continue;
      await _db
          .into(_db.settings)
          .insertOnConflictUpdate(
            SettingsCompanion.insert(key: key, value: encoded, updatedAt: now),
          );
    }
  });

  static Map<String, Object?> _toMap(AppSettings s) => {
    SettingKeys.themeMode: s.themeMode.code,
    SettingKeys.weightUnit: s.weightUnit.code,
    SettingKeys.weightStep: s.weightStep,
    SettingKeys.equipmentWeightSteps: {
      for (final MapEntry(:key, :value) in s.equipmentWeightSteps.entries)
        key.code: value,
    },
    SettingKeys.barWeights: {
      for (final MapEntry(:key, :value) in s.barWeights.entries)
        key.code: value,
    },
    SettingKeys.plates: s.plates,
    SettingKeys.durationStepSeconds: s.durationStepSeconds,
    SettingKeys.distanceStepMeters: s.distanceStepMeters,
    SettingKeys.effortScale: s.effortScale?.code ?? 'off',
    SettingKeys.defaultRestSeconds: s.defaultRestSeconds,
    SettingKeys.keepScreenOn: s.keepScreenOn,
    SettingKeys.autoProgression: s.autoProgression,
    SettingKeys.exactAlarmPrompted: s.exactAlarmPrompted,
    SettingKeys.assistantUrl: s.assistantUrl,
    SettingKeys.assistantModel: s.assistantModel,
    SettingKeys.planReminders: s.planReminders,
    SettingKeys.planReminderMinutes: s.planReminderMinutes,
  };

  /// Brakujące albo nieczytelne wartości przyjmują wartości domyślne.
  static AppSettings _fromRows(List<SettingRow> rows) {
    final values = <String, Object?>{};
    for (final row in rows) {
      try {
        values[row.key] = jsonDecode(row.value);
      } on FormatException {
        // Uszkodzona wartość: zostaje domyślna.
      }
    }
    const defaults = AppSettings();
    T pick<T>(String key, T fallback, T? Function(Object? raw) parse) {
      try {
        return parse(values[key]) ?? fallback;
      } on Object {
        return fallback;
      }
    }

    return AppSettings(
      themeMode: pick(
        SettingKeys.themeMode,
        defaults.themeMode,
        (raw) => tryEnumFromCode(AppThemeMode.values, raw),
      ),
      weightUnit: pick(
        SettingKeys.weightUnit,
        defaults.weightUnit,
        (raw) => tryEnumFromCode(WeightUnit.values, raw),
      ),
      weightStep: pick(
        SettingKeys.weightStep,
        defaults.weightStep,
        (raw) => raw is num && raw > 0 ? raw.toDouble() : null,
      ),
      equipmentWeightSteps: pick(
        SettingKeys.equipmentWeightSteps,
        defaults.equipmentWeightSteps,
        _equipmentMap,
      ),
      barWeights: pick(
        SettingKeys.barWeights,
        defaults.barWeights,
        _equipmentMap,
      ),
      plates: pick(
        SettingKeys.plates,
        defaults.plates,
        (raw) =>
            raw is List && raw.isNotEmpty && raw.every((v) => v is num && v > 0)
            ? [for (final v in raw) (v as num).toDouble()]
            : null,
      ),
      durationStepSeconds: pick(
        SettingKeys.durationStepSeconds,
        defaults.durationStepSeconds,
        (raw) => raw is int && raw > 0 ? raw : null,
      ),
      distanceStepMeters: pick(
        SettingKeys.distanceStepMeters,
        defaults.distanceStepMeters,
        (raw) => raw is int && raw > 0 ? raw : null,
      ),
      effortScale: values[SettingKeys.effortScale] == 'off'
          ? null
          : pick(
              SettingKeys.effortScale,
              defaults.effortScale,
              (raw) => tryEnumFromCode(EffortScale.values, raw),
            ),
      defaultRestSeconds: pick(
        SettingKeys.defaultRestSeconds,
        defaults.defaultRestSeconds,
        (raw) => raw is int && raw >= 0 ? raw : null,
      ),
      keepScreenOn: pick(
        SettingKeys.keepScreenOn,
        defaults.keepScreenOn,
        (raw) => raw is bool ? raw : null,
      ),
      autoProgression: pick(
        SettingKeys.autoProgression,
        defaults.autoProgression,
        (raw) => raw is bool ? raw : null,
      ),
      exactAlarmPrompted: pick(
        SettingKeys.exactAlarmPrompted,
        defaults.exactAlarmPrompted,
        (raw) => raw is bool ? raw : null,
      ),
      assistantUrl: pick(SettingKeys.assistantUrl, null, _nonEmptyText),
      assistantModel: pick(SettingKeys.assistantModel, null, _nonEmptyText),
      planReminders: pick(
        SettingKeys.planReminders,
        defaults.planReminders,
        (raw) => raw is bool ? raw : null,
      ),
      planReminderMinutes: pick(
        SettingKeys.planReminderMinutes,
        defaults.planReminderMinutes,
        (raw) => raw is int && raw >= 0 && raw < 24 * 60 ? raw : null,
      ),
    );
  }

  static String? _nonEmptyText(Object? raw) =>
      raw is String && raw.isNotEmpty ? raw : null;

  /// Obiekt kod sprzętu → liczba dodatnia; nieznany sprzęt i złe wartości
  /// są pomijane.
  static Map<Equipment, double>? _equipmentMap(Object? raw) =>
      raw is Map<String, Object?>
      ? {
          for (final MapEntry(:key, :value) in raw.entries)
            if (tryEnumFromCode(Equipment.values, key) case final equipment?)
              if (value is num && value > 0) equipment: value.toDouble(),
        }
      : null;
}
