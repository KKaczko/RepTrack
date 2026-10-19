import 'dart:math';

import 'package:collection/collection.dart';

import '../../../core/domain/training.dart';
import '../../exercises/domain/exercise.dart';
import 'workout_session.dart';

/// Skąd pochodzi wartość pola serii (ADR 0006).
enum HintSource {
  /// Wpisana przez użytkownika w tej sesji.
  entered,

  /// Podpowiedź z poprzedniego wykonania ćwiczenia.
  previous,

  /// Podpowiedź z planu (szablonu) albo wartość domyślna.
  plan,

  /// Wartość wcześniejszej serii tego samego rodzaju w bieżącym treningu,
  /// gdy brak poprzedniego wykonania i planu (np. pierwsze wykonanie).
  earlierSet,
}

/// Wartość pola z informacją o źródle.
typedef HintedValue = ({int value, HintSource source});

/// Wartości serii do wyświetlenia i zatwierdzenia. Pole null oznacza, że
/// ćwiczenie go nie mierzy albo nie ma żadnej podpowiedzi.
final class SetHint {
  const SetHint({this.weightG, this.reps, this.durationS, this.distanceM});

  final HintedValue? weightG;
  final HintedValue? reps;
  final HintedValue? durationS;
  final HintedValue? distanceM;

  /// Czy wszystkie mierzone pola mają wartość, więc serię można zatwierdzić
  /// jednym tapnięciem.
  bool isComplete(Measurement m) =>
      (!m.weight || weightG != null) &&
      (!m.reps || reps != null) &&
      (!m.duration || durationS != null) &&
      (!m.distance || distanceM != null);
}

/// Mierzone pole serii.
enum SetField { weight, reps, duration, distance }

/// Pola mierzone przez ćwiczenie, w stałej kolejności.
List<SetField> measuredFields(Measurement m) => [
  if (m.weight) SetField.weight,
  if (m.reps) SetField.reps,
  if (m.duration) SetField.duration,
  if (m.distance) SetField.distance,
];

/// Wartość pola serii (wpisana albo zatwierdzona).
int? setValue(SessionSet set, SetField field) => switch (field) {
  SetField.weight => set.weightG,
  SetField.reps => set.reps,
  SetField.duration => set.durationS,
  SetField.distance => set.distanceM,
};

/// Seria z nową wartością pola; null czyści wpis i przywraca podpowiedź.
SessionSet withSetValue(SessionSet set, SetField field, int? value) =>
    switch (field) {
      SetField.weight => set.copyWith(weightG: value),
      SetField.reps => set.copyWith(reps: value),
      SetField.duration => set.copyWith(durationS: value),
      SetField.distance => set.copyWith(distanceM: value),
    };

/// Podpowiedź pola serii.
HintedValue? hintValue(SetHint hint, SetField field) => switch (field) {
  SetField.weight => hint.weightG,
  SetField.reps => hint.reps,
  SetField.duration => hint.durationS,
  SetField.distance => hint.distanceM,
};

/// Mierzone pola bez wartości: trzeba je uzupełnić przed zatwierdzeniem.
List<SetField> missingFields(SetHint hint, Measurement m) => [
  for (final field in measuredFields(m))
    if (hintValue(hint, field) == null) field,
];

/// Seria jest rozgrzewkowa; pozostałe typy to serie robocze.
bool isWarmup(SessionSet set) => set.setType == SetType.warmup;

/// Dopasowuje serie poprzedniego wykonania do bieżących: robocze po
/// kolejności wśród roboczych, rozgrzewkowe wśród rozgrzewkowych (ADR 0006).
/// Uwzględnia tylko zatwierdzone serie poprzedniego wykonania.
/// Zwraca mapę id bieżącej serii → seria poprzednia.
Map<String, SessionSet> matchPreviousSets(
  List<SessionSet> current,
  List<SessionSet> previous,
) {
  final prev = previous
      .where((s) => s.isCompleted)
      .sortedBy<num>((s) => s.position);
  final prevWarmups = prev.where(isWarmup).toList();
  final prevWorking = prev.whereNot(isWarmup).toList();
  var warmupIndex = 0;
  var workingIndex = 0;
  final result = <String, SessionSet>{};
  for (final set in current.sortedBy<num>((s) => s.position)) {
    if (isWarmup(set)) {
      if (warmupIndex < prevWarmups.length) {
        result[set.id] = prevWarmups[warmupIndex];
      }
      warmupIndex++;
    } else {
      if (workingIndex < prevWorking.length) {
        result[set.id] = prevWorking[workingIndex];
      }
      workingIndex++;
    }
  }
  return result;
}

/// Podpowiedź dla serii: wartość wpisana → poprzednie wykonanie → plan →
/// wcześniejsza seria tego treningu ([earlier]). Dla masy ciała
/// z dociążeniem i wspomagania brak ciężaru oznacza na końcu 0.
SetHint hintForSet({
  required SessionSet set,
  required SessionSet? previous,
  required Measurement measurement,
  required LoadMode loadMode,
  SetHint? earlier,
}) {
  HintedValue? pick(
    int? entered,
    int? fromPrevious,
    int? fromPlan,
    HintedValue? fromEarlier, {
    int? fallback,
  }) {
    if (entered != null) return (value: entered, source: HintSource.entered);
    if (fromPrevious != null) {
      return (value: fromPrevious, source: HintSource.previous);
    }
    if (fromPlan != null) return (value: fromPlan, source: HintSource.plan);
    if (fromEarlier != null) {
      return (value: fromEarlier.value, source: HintSource.earlierSet);
    }
    if (fallback != null) return (value: fallback, source: HintSource.plan);
    return null;
  }

  final defaultWeight =
      loadMode == LoadMode.weightedBodyweight || loadMode == LoadMode.assisted
      ? 0
      : null;
  final planReps = set.targetKind == TargetKind.reps
      ? set.targetMin ?? set.targetMax
      : null;
  final planDuration = set.targetKind == TargetKind.duration
      ? set.targetMin ?? set.targetMax
      : null;

  return SetHint(
    weightG: measurement.weight
        ? pick(
            set.weightG,
            previous?.weightG,
            set.targetWeightG,
            earlier?.weightG,
            fallback: defaultWeight,
          )
        : null,
    reps: measurement.reps
        ? pick(set.reps, previous?.reps, planReps, earlier?.reps)
        : null,
    durationS: measurement.duration
        ? pick(
            set.durationS,
            previous?.durationS,
            planDuration,
            earlier?.durationS,
          )
        : null,
    distanceM: measurement.distance
        ? pick(set.distanceM, previous?.distanceM, null, earlier?.distanceM)
        : null,
  );
}

/// Podpowiedzi wszystkich serii ćwiczenia (id serii → podpowiedź). Seria
/// dziedziczy brakujące wartości po wcześniejszej serii tego samego rodzaju
/// (rozgrzewkowej albo roboczej), więc po wpisaniu ciężaru w pierwszej serii
/// kolejne zatwierdza się jednym tapnięciem także przy pierwszym wykonaniu.
Map<String, SetHint> hintsForExercise(
  SessionExercise exercise,
  List<SessionSet> previousSets,
) {
  final matched = matchPreviousSets(exercise.sets, previousSets);
  final lastByKind = <bool, SetHint>{};
  final result = <String, SetHint>{};
  for (final set in exercise.sets.sortedBy<num>((s) => s.position)) {
    final hint = hintForSet(
      set: set,
      previous: matched[set.id],
      measurement: exercise.measurementSnapshot,
      loadMode: exercise.loadModeSnapshot,
      earlier: lastByKind[isWarmup(set)],
    );
    result[set.id] = hint;
    lastByKind[isWarmup(set)] = hint;
  }
  return result;
}

/// Seria nie ma kompletu wartości do zatwierdzenia.
final class IncompleteSetException implements Exception {
  const IncompleteSetException();

  @override
  String toString() => 'IncompleteSetException';
}

/// Zatwierdza serię: brakujące pola przyjmują wartości z podpowiedzi,
/// a seria dostaje `completedAt`. To jedyne miejsce, w którym seria staje
/// się wykonana; podpowiedzi nigdy nie zatwierdzają jej same.
SessionSet confirmSet(
  SessionSet set,
  SetHint hint,
  Measurement measurement,
  DateTime now,
) {
  if (!hint.isComplete(measurement)) throw const IncompleteSetException();
  return set.copyWith(
    weightG: measurement.weight ? hint.weightG!.value : set.weightG,
    reps: measurement.reps ? hint.reps!.value : set.reps,
    durationS: measurement.duration ? hint.durationS!.value : set.durationS,
    distanceM: measurement.distance ? hint.distanceM!.value : set.distanceM,
    completedAt: now.toUtc(),
  );
}

/// Cofa zatwierdzenie; wpisane wartości zostają.
SessionSet uncompleteSet(SessionSet set) => set.copyWith(completedAt: null);

/// Pierwsza niezatwierdzona seria ćwiczenia albo null, gdy wszystkie są
/// zatwierdzone.
SessionSet? nextOpenSet(SessionExercise exercise) => exercise.sets
    .sortedBy<num>((s) => s.position)
    .firstWhereOrNull((s) => !s.isCompleted);

/// Ćwiczenie z następną niezatwierdzoną serią, szukane od [currentExerciseId]
/// w kolejności sesji, a potem od początku (pominięte wcześniej ćwiczenia).
/// Null, gdy wszystkie serie są zatwierdzone.
SessionExercise? nextExerciseToDo(
  WorkoutSession session,
  String? currentExerciseId,
) {
  final list = session.exercises.sortedBy<num>((e) => e.position);
  final start = max(0, list.indexWhere((e) => e.id == currentExerciseId));
  for (var i = 0; i < list.length; i++) {
    final exercise = list[(start + i) % list.length];
    if (nextOpenSet(exercise) != null) return exercise;
  }
  return null;
}
