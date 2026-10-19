/// Enum ze stabilnym kodem tekstowym zapisywanym w bazie i backupie (ADR 0013).
///
/// Kod jest niezależny od nazwy wartości w Dart: zmiana nazwy w kodzie nie
/// zmienia danych. Kody są w snake_case. Wolno dodawać nowe wartości, a zmiana
/// lub usunięcie kodu wymaga migracji bazy i formatu backupu.
abstract interface class CodedEnum {
  String get code;
}

/// Wartość enumu o kodzie [code]. Rzuca [FormatException] dla nieznanego kodu.
T enumFromCode<T extends CodedEnum>(List<T> values, String code) {
  for (final value in values) {
    if (value.code == code) return value;
  }
  throw FormatException('Nieznany kod $T', code);
}

/// Jak [enumFromCode], ale zwraca null dla nieznanego lub brakującego kodu.
T? tryEnumFromCode<T extends CodedEnum>(List<T> values, Object? code) {
  for (final value in values) {
    if (value.code == code) return value;
  }
  return null;
}
