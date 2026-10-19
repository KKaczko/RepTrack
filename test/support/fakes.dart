import 'package:reptrack/core/domain/ids.dart';

/// Deterministyczny generator identyfikatorów do testów.
final class SequentialIds implements IdGenerator {
  SequentialIds([this.prefix = 'id']);

  final String prefix;
  var _next = 0;

  @override
  String newId() => '$prefix-${_next++}';
}
