import 'dart:convert';

import '../../../core/database/app_database.dart';
import '../../../core/database/setting_keys.dart';
import '../../../core/domain/clock.dart';
import '../../../core/domain/coded_enum.dart';
import '../../../core/domain/training.dart';
import '../../../core/domain/units.dart';
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
    SettingKeys.effortScale: s.effortScale?.code ?? 'off',
    SettingKeys.defaultRestSeconds: s.defaultRestSeconds,
    SettingKeys.keepScreenOn: s.keepScreenOn,
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
    );
  }
}
