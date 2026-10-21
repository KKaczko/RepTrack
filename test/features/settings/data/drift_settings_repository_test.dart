import 'package:flutter_test/flutter_test.dart';
import 'package:reptrack/core/database/app_database.dart';
import 'package:reptrack/core/domain/units.dart';
import 'package:reptrack/features/exercises/domain/exercise.dart';
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
      equipmentWeightSteps: {Equipment.dumbbell: 2, Equipment.kettlebell: 4},
      barWeights: {Equipment.barbell: 15, Equipment.ezBar: 7.5},
      plates: [20, 10, 5, 2.5],
      durationStepSeconds: 30,
      distanceStepMeters: 250,
      effortScale: null,
      defaultRestSeconds: 90,
      keepScreenOn: false,
      autoProgression: false,
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

  test('niepoprawny krok czasu lub dystansu daje wartość domyślną', () async {
    await repo.save(
      const AppSettings(durationStepSeconds: 15, distanceStepMeters: 50),
    );
    await db.customStatement(
      "UPDATE settings SET value = '0' WHERE key = 'duration_step_seconds'",
    );
    await db.customStatement(
      "UPDATE settings SET value = '2.5' WHERE key = 'distance_step_meters'",
    );

    final loaded = await repo.load();

    expect((loaded.durationStepSeconds, loaded.distanceStepMeters), (5, 100));
  });

  test('kroki dla sprzętu: nieznany sprzęt i zły krok są pomijane', () async {
    await repo.save(const AppSettings());
    await db.customStatement(
      'UPDATE settings SET value = '
      """'{"dumbbell": 2, "rocket": 3, "machine": -5}' """
      "WHERE key = 'equipment_weight_steps'",
    );

    final loaded = await repo.load();

    expect(loaded.equipmentWeightSteps, {Equipment.dumbbell: 2.0});
  });
}
