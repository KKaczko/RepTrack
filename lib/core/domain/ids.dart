import 'package:uuid/uuid.dart';

/// Źródło identyfikatorów rekordów (ADR 0003).
abstract interface class IdGenerator {
  String newId();
}

/// UUIDv7 generowane na urządzeniu: uporządkowane czasowo, w postaci tekstowej.
final class UuidV7Generator implements IdGenerator {
  const UuidV7Generator();

  static const _uuid = Uuid();

  @override
  String newId() => _uuid.v7();
}
