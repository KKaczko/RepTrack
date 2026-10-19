import 'package:drift/drift.dart';

/// Zdarzenie przy każdej zmianie którejś z [tables] (i od razu po
/// subskrypcji). Służy do obserwowania agregatów złożonych z kilku tabel.
///
/// Drift współdzieli obserwowane zapytania o identycznym SQL niezależnie od
/// `readsFrom`, dlatego każdy agregat musi podać własny, stały [key]. Wspólne
/// `SELECT 1` sprawiało, że zmiany szablonów nie docierały do listy, gdy
/// jednocześnie obserwowano trening.
Stream<void> watchTables(
  DatabaseConnectionUser db,
  String key,
  Set<ResultSetImplementation<dynamic, dynamic>> tables,
) {
  assert(RegExp(r'^[a-z_]+$').hasMatch(key), 'klucz musi być stałą nazwą');
  return db
      .customSelect("SELECT '$key' AS watched", readsFrom: tables)
      .watch()
      .map((_) {});
}
