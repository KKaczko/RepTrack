import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reptrack/core/database/app_database.dart';

import '../../support/test_database.dart';
import 'generated/schema.dart';

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

  test('schemat v1 ze zrzutu odpowiada bieżącej bazie', () async {
    final connection = await verifier.startAt(1);
    final db = AppDatabase(connection);
    addTearDown(db.close);

    await verifier.migrateAndValidate(db, 1);
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
