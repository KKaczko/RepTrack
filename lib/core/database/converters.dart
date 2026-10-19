import 'dart:convert';

import 'package:drift/drift.dart';

import '../domain/coded_enum.dart';
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

/// Enum jako jego stabilny kod snake_case (ADR 0013), nie nazwa w Dart.
final class CodedEnumConverter<T extends CodedEnum>
    extends TypeConverter<T, String> {
  const CodedEnumConverter(this.values);

  final List<T> values;

  @override
  T fromSql(String fromDb) => enumFromCode(values, fromDb);

  @override
  String toSql(T value) => value.code;
}

/// Lista enumów jako tablica JSON stabilnych kodów.
final class CodedEnumListConverter<T extends CodedEnum>
    extends TypeConverter<List<T>, String> {
  const CodedEnumListConverter(this.values);

  final List<T> values;

  @override
  List<T> fromSql(String fromDb) => [
    for (final code in (jsonDecode(fromDb) as List<dynamic>).cast<String>())
      enumFromCode(values, code),
  ];

  @override
  String toSql(List<T> value) => jsonEncode([for (final v in value) v.code]);
}
