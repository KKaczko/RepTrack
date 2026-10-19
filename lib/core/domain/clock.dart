/// Źródło bieżącego czasu. Testy podmieniają je na stały zegar.
abstract interface class Clock {
  /// Bieżący moment w UTC.
  DateTime nowUtc();
}

final class SystemClock implements Clock {
  const SystemClock();

  @override
  DateTime nowUtc() => DateTime.now().toUtc();
}

/// Zegar o ustalonym czasie, do testów i podglądów.
final class FixedClock implements Clock {
  FixedClock(DateTime now) : _now = now.toUtc();

  DateTime _now;

  @override
  DateTime nowUtc() => _now;

  void advance(Duration duration) => _now = _now.add(duration);
}
