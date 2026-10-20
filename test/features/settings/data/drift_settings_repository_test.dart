import 'package:flutter_test/flutter_test.dart';
import 'package:reptrack/core/database/app_database.dart';
import 'package:reptrack/core/domain/units.dart';
import 'package:reptrack/features/settings/data/drift_settings_repository.dart';
import 'package:reptrack/features/settings/domain/app_settings.dart';

import '../../../support/test_database.dart';

void main() {
  late AppDatabase db;
  late DriftSettingsRepository repo;

  setUp(() {
    db = memoryDatabase();
    repo = DriftSettingsRepository(db, testClock());
  });
  tearDown(() => db.close());

  test('pusta baza daje wartości domyślne', () async {
    expect(await repo.load(), const AppSettings());
  });

  test('zapis i odczyt, także wyłączonej skali wysiłku', () async {
    const settings = AppSettings(
      themeMode: AppThemeMode.light,
      weightUnit: WeightUnit.lb,
      weightStep: 5,
      effortScale: null,
      defaultRestSeconds: 90,
      keepScreenOn: false,
      assistantUrl: 'http://192.168.1.10:11434',
      assistantModel: 'qwen3.5:4b',
      planReminders: true,
      planReminderMinutes: 18 * 60 + 30,
    );

    await repo.save(settings);

    expect(await repo.load(), settings);
  });

  test('uszkodzona wartość nie psuje pozostałych ustawień', () async {
    await repo.save(const AppSettings(defaultRestSeconds: 75));
    await db.customStatement(
      "UPDATE settings SET value = '{nie-json' WHERE key = 'weight_unit'",
    );
    await db.customStatement(
      "UPDATE settings SET value = '\"tydzien\"' WHERE key = 'theme_mode'",
    );

    final loaded = await repo.load();

    expect(loaded.weightUnit, WeightUnit.kg);
    expect(loaded.themeMode, AppThemeMode.dark);
    expect(loaded.defaultRestSeconds, 75);
  });
}
