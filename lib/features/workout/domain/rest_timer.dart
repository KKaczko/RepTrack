import 'workout_session.dart';

/// Krok zmiany przerwy przyciskami ±15 s (spec. 5.3).
const restAdjustStep = Duration(seconds: 15);

/// Długość przerwy po serii: z planu albo domyślna z ustawień.
Duration restAfter(SessionSet set, int defaultRestSeconds) =>
    Duration(seconds: set.restSeconds ?? defaultRestSeconds);

/// Koniec przerwy po zmianie o [delta]. Zwraca null, gdy przerwa by się
/// skończyła (koniec nie później niż [now]).
DateTime? adjustRestEnd(DateTime? endsAt, DateTime now, Duration delta) {
  if (endsAt == null) return null;
  final adjusted = endsAt.add(delta);
  return adjusted.isAfter(now) ? adjusted.toUtc() : null;
}

/// Pozostały czas przerwy; zero, gdy przerwa się skończyła albo jej nie ma.
Duration restRemaining(DateTime? endsAt, DateTime now) {
  if (endsAt == null) return Duration.zero;
  final left = endsAt.difference(now);
  return left.isNegative ? Duration.zero : left;
}
