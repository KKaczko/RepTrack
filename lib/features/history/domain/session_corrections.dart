import 'package:collection/collection.dart';

import '../../../core/domain/ids.dart';
import '../../workout/domain/session_editing.dart';
import '../../workout/domain/workout_session.dart';

/// Korekty zakończonego treningu w historii (spec. 5.4): zmiana wartości,
/// dodanie i usunięcie serii. Usuwanie i zmianę wartości obsługują funkcje
/// z `session_editing.dart`.

/// Moment zatwierdzenia serii dopisanej albo zatwierdzonej przy korekcie:
/// koniec treningu (albo start, gdy końca brak).
DateTime loggedAt(WorkoutSession session) =>
    session.endedAt ?? session.startedAt;

/// Dopisuje zatwierdzoną serię z planem i wartościami ostatniej serii
/// ćwiczenia, gotową do poprawienia.
WorkoutSession appendLoggedSet(
  WorkoutSession session,
  String exerciseId,
  IdGenerator ids,
) {
  final exercise = session.exercises.firstWhere((e) => e.id == exerciseId);
  final last = sortedSets(exercise).lastOrNull;
  final added = addSet(session, exerciseId, ids);
  final newSet = sortedSets(
    added.exercises.firstWhere((e) => e.id == exerciseId),
  ).last;
  return updateSet(
    added,
    exerciseId,
    newSet.id,
    (s) => s.copyWith(
      weightG: last?.weightG,
      reps: last?.reps,
      durationS: last?.durationS,
      distanceM: last?.distanceM,
      completedAt: loggedAt(session),
    ),
  );
}

/// Zatwierdza serię przy korekcie albo cofa zatwierdzenie. Zatwierdzona
/// wcześniej seria zachowuje swój czas.
SessionSet setLogged(
  SessionSet set,
  WorkoutSession session, {
  required bool logged,
}) => logged
    ? set.copyWith(completedAt: set.completedAt ?? loggedAt(session))
    : set.copyWith(completedAt: null);
