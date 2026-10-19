import 'package:drift/drift.dart';

/// Zapisuje [candidate], tylko gdy różni się od [existing].
///
/// [candidate] musi nieść znaczniki czasu z [existing] (albo `now` dla nowego
/// wiersza); [touch] ustawia w nim `updated_at = now`. Dzięki temu
/// niezmienione wiersze agregatu zachowują `updated_at`, co jest potrzebne
/// przyszłej synchronizacji „ostatni zapis wygrywa” (ADR 0003).
Future<void> upsertIfChanged<T extends Table, R extends DataClass>(
  DatabaseConnectionUser db,
  TableInfo<T, R> table, {
  required R? existing,
  required R candidate,
  required R Function(R row) touch,
}) async {
  if (existing == candidate) return;
  // `insertOnConflictUpdate` pomija kolumny null w części UPDATE
  // (`toColumns(true)`), więc wyczyszczone pole (np. przywrócone
  // dziedziczenie, cofnięte zatwierdzenie serii) nie trafiłoby do bazy.
  final values = RawValuesInsertable<R>(
    (touch(candidate) as Insertable<R>).toColumns(false),
  );
  await db.into(table).insert(values, onConflict: DoUpdate((_) => values));
}

/// Miękko usuwa nieusunięte wiersze [table], w których [column] = [value].
Future<void> softDeleteWhere(
  DatabaseConnectionUser db,
  TableInfo<Table, Object?> table, {
  required String column,
  required String value,
  required DateTime now,
}) => db.customUpdate(
  'UPDATE ${table.actualTableName} SET deleted_at = ?1, updated_at = ?1 '
  'WHERE $column = ?2 AND deleted_at IS NULL',
  variables: [
    Variable.withInt(now.toUtc().millisecondsSinceEpoch),
    Variable.withString(value),
  ],
  updates: {table},
  updateKind: UpdateKind.update,
);
