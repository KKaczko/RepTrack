import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reptrack/core/database/app_database.dart';

import '../../support/test_database.dart';
import 'generated/schema.dart';
import 'generated/schema_v1.dart' as v1;
import 'generated/schema_v2.dart' as v2;
import 'generated/schema_v3.dart' as v3;

/// Testy migracji na zapisanych wersjach schematu (`drift_schemas/`).
///
/// Przy każdej nowej wersji: podbij `schemaVersion`, uruchom
/// `dart run drift_dev make-migrations` oraz
/// `dart run drift_dev schema generate drift_schemas/app_database/ test/drift/app_database/generated/`
/// i dodaj test migracji vN → vN+1 z danymi.
void main() {
  late SchemaVerifier verifier;

  setUpAll(() {
    verifier = SchemaVerifier(GeneratedHelper());
  });

  test('schemat v3 ze zrzutu odpowiada bieżącej bazie', () async {
    final connection = await verifier.startAt(3);
    final db = AppDatabase(connection);
    addTearDown(db.close);

    await verifier.migrateAndValidate(db, 3);
  });

  test(
    'v1 → v3: dane zostają, dochodzą puste tabele planu i zamienników',
    () async {
      final schema = await verifier.schemaAt(1);
      final before = v1.DatabaseAtV1(schema.newConnection());
      await before
          .into(before.templates)
          .insert(
            const v1.TemplatesData(
              id: 'tpl',
              createdAt: 1,
              updatedAt: 1,
              name: 'Push A',
            ),
          );
      await before
          .into(before.settings)
          .insert(
            const v1.SettingsData(
              key: 'weight_unit',
              value: '"kg"',
              updatedAt: 1,
            ),
          );
      await before.close();

      final db = AppDatabase(schema.newConnection());
      addTearDown(db.close);
      await verifier.migrateAndValidate(db, 3);

      final after = v3.DatabaseAtV3(schema.newConnection());
      addTearDown(after.close);
      final templates = await after.select(after.templates).get();
      expect([for (final t in templates) t.name], ['Push A']);
      expect(await after.select(after.settings).get(), hasLength(1));
      expect(await after.select(after.weeklyPlans).get(), isEmpty);
      expect(await after.select(after.weeklyPlanDays).get(), isEmpty);
      expect(await after.select(after.plannedDays).get(), isEmpty);
      expect(await after.select(after.exerciseSubstitutes).get(), isEmpty);
    },
  );

  test('v2 → v3: plan zostaje, dochodzi pusta tabela zamienników', () async {
    final schema = await verifier.schemaAt(2);
    final before = v2.DatabaseAtV2(schema.newConnection());
    await before
        .into(before.weeklyPlans)
        .insert(
          const v2.WeeklyPlansData(
            id: 'wp',
            createdAt: 1,
            updatedAt: 1,
            startsOn: '2026-10-19',
          ),
        );
    await before.close();

    final db = AppDatabase(schema.newConnection());
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, 3);

    final after = v3.DatabaseAtV3(schema.newConnection());
    addTearDown(after.close);
    final plans = await after.select(after.weeklyPlans).get();
    expect([for (final p in plans) p.startsOn], ['2026-10-19']);
    expect(await after.select(after.exerciseSubstitutes).get(), isEmpty);
  });

  test('świeża baza (onCreate) ma oczekiwany schemat', () async {
    final db = memoryDatabase();
    addTearDown(db.close);

    await db.validateDatabaseSchema();
  });

  test('bieżąca wersja schematu ma swój zrzut', () {
    expect(GeneratedHelper.versions, contains(memoryDatabase().schemaVersion));
  });
}
