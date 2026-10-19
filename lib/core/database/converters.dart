import 'dart:convert';

import 'package:drift/drift.dart';

import '../domain/local_date.dart';

/// Moment czasu jako epoch ms UTC (docs/data-model.md).
final class UtcMillisConverter extends TypeConverter<DateTime, int> {
  const UtcMillisConverter();

  @override
  DateTime fromSql(int fromDb) =>
      DateTime.fromMillisecondsSinceEpoch(fromDb, isUtc: true);

  @override
  int toSql(DateTime value) => value.toUtc().millisecondsSinceEpoch;
}

/// Data lokalna jako tekst `YYYY-MM-DD`.
final class LocalDateConverter extends TypeConverter<LocalDate, String> {
  const LocalDateConverter();

  @override
  LocalDate fromSql(String fromDb) => LocalDate.parse(fromDb);

  @override
  String toSql(LocalDate value) => value.toIso();
}

/// Lista tekstów jako tablica JSON.
final class StringListConverter extends TypeConverter<List<String>, String> {
  const StringListConverter();

  @override
  List<String> fromSql(String fromDb) =>
      (jsonDecode(fromDb) as List<dynamic>).cast<String>();

  @override
  String toSql(List<String> value) => jsonEncode(value);
}

/// Lista enumów jako tablica JSON stabilnych kodów (nazw wartości).
final class EnumListConverter<T extends Enum>
    extends TypeConverter<List<T>, String> {
  const EnumListConverter(this.values);

  final List<T> values;

  @override
  List<T> fromSql(String fromDb) => [
    for (final name in (jsonDecode(fromDb) as List<dynamic>).cast<String>())
      values.byName(name),
  ];

  @override
  String toSql(List<T> value) => jsonEncode([for (final v in value) v.name]);
}
