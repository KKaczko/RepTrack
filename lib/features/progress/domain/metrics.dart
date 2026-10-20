import 'package:collection/collection.dart';

import '../../../core/domain/local_date.dart';
import '../../../core/domain/training.dart';
import '../../exercises/domain/exercise.dart';
import '../../workout/domain/workout_session.dart';

/// Metryki progresu (ADR 0007).

/// Najwyższa liczba powtórzeń, dla której liczymy szacowany 1RM.
const maxRepsForEstimate = 10;

/// Najwyższa liczba powtórzeń śledzona w rekordach „ciężar dla N powt.”.
const maxRepsForRecords = 15;

/// Szacowany 1RM wzorem Epleya: ciężar × (1 + powtórzenia / 30), w gramach.
/// Dla 1 powtórzenia to sam ciężar. Null dla 0 albo ponad 10 powtórzeń.
double? estimatedOneRepMax(int weightG, int reps) {
  if (reps < 1 || reps > maxRepsForEstimate || weightG <= 0) return null;
  if (reps == 1) return weightG.toDouble();
  return weightG * (1 + reps / 30);
}

/// Czy tryb obciążenia daje metryki ciężaru (zewnętrzne i dociążenie).
bool hasWeightMetrics(LoadMode mode) =>
    mode == LoadMode.external || mode == LoadMode.weightedBodyweight;

/// Seria wliczana do metryk: zatwierdzona i nie rozgrzewkowa.
bool countsForMetrics(SessionSet set) =>
    set.isCompleted && set.setType != SetType.warmup;

/// Objętość serii w gramach (ciężar × powtórzenia), bez rozgrzewek.
int setVolumeG(SessionSet set, LoadMode mode) {
  if (!countsForMetrics(set) || !hasWeightMetrics(mode)) return 0;
  final weight = set.weightG;
  final reps = set.reps;
  if (weight == null || reps == null) return 0;
  return weight * reps;
}

/// Objętość ćwiczenia w sesji.
int exerciseVolumeG(SessionExercise exercise) => exercise.sets.fold(
  0,
  (sum, set) => sum + setVolumeG(set, exercise.loadModeSnapshot),
);

/// Objętość całej sesji.
int sessionVolumeG(WorkoutSession session) =>
    session.exercises.fold(0, (sum, e) => sum + exerciseVolumeG(e));

/// Seria z trybem obciążenia z chwili wykonania.
typedef PerformedSet = ({SessionSet set, LoadMode loadMode});

/// Rekordy ćwiczenia.
final class ExerciseRecords {
  const ExerciseRecords({
    this.bestE1rmG,
    this.bestWeightForReps = const {},
    this.maxReps,
  });

  /// Najlepszy szacowany 1RM (g).
  final double? bestE1rmG;

  /// Najcięższa seria z co najmniej N powtórzeniami: N → gramy.
  final Map<int, int> bestWeightForReps;

  /// Najwięcej powtórzeń w serii (ćwiczenia z masą ciała).
  final int? maxReps;

  bool get isEmpty =>
      bestE1rmG == null && bestWeightForReps.isEmpty && maxReps == null;
}

/// Liczy rekordy z serii roboczych.
ExerciseRecords computeRecords(Iterable<PerformedSet> sets) {
  double? bestE1rm;
  final bestForReps = <int, int>{};
  int? maxReps;
  for (final (:set, :loadMode) in sets) {
    if (!countsForMetrics(set)) continue;
    final reps = set.reps;
    if (reps == null) continue;
    if (loadMode == LoadMode.bodyweight) {
      maxReps = maxReps == null || reps > maxReps ? reps : maxReps;
      continue;
    }
    final weight = set.weightG;
    if (!hasWeightMetrics(loadMode) || weight == null || weight <= 0) continue;
    final e1rm = estimatedOneRepMax(weight, reps);
    if (e1rm != null && (bestE1rm == null || e1rm > bestE1rm)) bestE1rm = e1rm;
    for (var n = 1; n <= reps && n <= maxRepsForRecords; n++) {
      final current = bestForReps[n];
      if (current == null || weight > current) bestForReps[n] = weight;
    }
  }
  return ExerciseRecords(
    bestE1rmG: bestE1rm,
    bestWeightForReps: bestForReps,
    maxReps: maxReps,
  );
}

/// Nowy rekord ustanowiony w sesji.
sealed class RecordEvent {
  const RecordEvent();
}

final class E1rmRecord extends RecordEvent {
  const E1rmRecord(this.e1rmG);

  final double e1rmG;
}

final class RepsWeightRecord extends RecordEvent {
  const RepsWeightRecord({required this.reps, required this.weightG});

  final int reps;
  final int weightG;
}

final class MaxRepsRecord extends RecordEvent {
  const MaxRepsRecord(this.reps);

  final int reps;
}

/// Rekordy pobite w sesji względem historii sprzed sesji. Gdy historia jest
/// pusta, nic nie jest rekordem (pierwszy trening to punkt odniesienia).
///
/// Dla „ciężaru dla N powt.” raportujemy tylko najwyższe pobite N.
List<RecordEvent> newRecords({
  required ExerciseRecords before,
  required ExerciseRecords session,
}) {
  if (before.isEmpty) return const [];
  final events = <RecordEvent>[];
  final e1rm = session.bestE1rmG;
  if (e1rm != null && (before.bestE1rmG == null || e1rm > before.bestE1rmG!)) {
    events.add(E1rmRecord(e1rm));
  }
  final beaten = session.bestWeightForReps.entries
      .where((entry) {
        final old = before.bestWeightForReps[entry.key];
        return old == null || entry.value > old;
      })
      .sortedBy<num>((entry) => entry.key);
  if (beaten.isNotEmpty) {
    final top = beaten.last;
    events.add(RepsWeightRecord(reps: top.key, weightG: top.value));
  }
  final reps = session.maxReps;
  if (reps != null && (before.maxReps == null || reps > before.maxReps!)) {
    events.add(MaxRepsRecord(reps));
  }
  return events;
}

/// Najlepszy szacowany 1RM w ćwiczeniu sesji (serie robocze, ADR 0007).
double? bestEstimatedOneRepMax(SessionExercise exercise) => computeRecords([
  for (final set in exercise.sets)
    (set: set, loadMode: exercise.loadModeSnapshot),
]).bestE1rmG;

/// Punkt wykresu: dzień treningu i wartość.
typedef ChartPoint = ({LocalDate date, double value});

/// Objętość ćwiczenia na dzień treningu (gramy, suma treningów z tego dnia),
/// od najstarszego. Dni bez objętości (masa ciała, wspomaganie) są pomijane.
List<ChartPoint> volumeTrend(
  Iterable<({LocalDate date, SessionExercise exercise})> performances,
) {
  final total = <LocalDate, double>{};
  for (final p in performances) {
    final volume = exerciseVolumeG(p.exercise);
    if (volume <= 0) continue;
    total[p.date] = (total[p.date] ?? 0) + volume;
  }
  return _byDate(total);
}

List<ChartPoint> _byDate(Map<LocalDate, double> values) => [
  for (final date in values.keys.sorted()) (date: date, value: values[date]!),
];

/// Rekord z dniem, w którym padł po raz pierwszy.
typedef DatedValue<T> = ({T value, LocalDate date});

/// Rekordy ćwiczenia z datami (ekran ćwiczenia, zakładka Rekordy).
final class DatedRecords {
  const DatedRecords({
    this.bestE1rmG,
    this.bestWeightForReps = const {},
    this.maxReps,
  });

  final DatedValue<double>? bestE1rmG;

  /// N powtórzeń → najcięższa seria z co najmniej N powtórzeniami.
  final Map<int, DatedValue<int>> bestWeightForReps;
  final DatedValue<int>? maxReps;

  bool get isEmpty =>
      bestE1rmG == null && bestWeightForReps.isEmpty && maxReps == null;
}

/// Rekordy z datą pierwszego osiągnięcia. Remis nie przesuwa daty.
DatedRecords datedRecords(
  Iterable<({LocalDate date, SessionExercise exercise})> performances,
) {
  DatedValue<double>? e1rm;
  final forReps = <int, DatedValue<int>>{};
  DatedValue<int>? maxReps;
  final ordered = performances.sortedBy<LocalDate>((p) => p.date);
  for (final p in ordered) {
    final records = computeRecords([
      for (final set in p.exercise.sets)
        (set: set, loadMode: p.exercise.loadModeSnapshot),
    ]);
    if (records.bestE1rmG case final value?
        when e1rm == null || value > e1rm.value) {
      e1rm = (value: value, date: p.date);
    }
    for (final MapEntry(key: reps, value: weight)
        in records.bestWeightForReps.entries) {
      final old = forReps[reps];
      if (old == null || weight > old.value) {
        forReps[reps] = (value: weight, date: p.date);
      }
    }
    if (records.maxReps case final value?
        when maxReps == null || value > maxReps.value) {
      maxReps = (value: value, date: p.date);
    }
  }
  return DatedRecords(
    bestE1rmG: e1rm,
    bestWeightForReps: forReps,
    maxReps: maxReps,
  );
}

/// Rekordy „ciężar dla N powt.” bez wierszy, które wynikają z rekordu dla
/// większej liczby powtórzeń: 85 kg × 8 sprawia, że „≥ 5 powt.: 85 kg” nic
/// nie dodaje. Zostaje N, dla którego ciężar jest większy niż dla N + 1.
List<({int reps, DatedValue<int> best})> distinctRepRecords(
  Map<int, DatedValue<int>> bestWeightForReps,
) {
  final reps = bestWeightForReps.keys.toList()..sort();
  return [
    for (final n in reps)
      if ((bestWeightForReps[n + 1]?.value ?? -1) < bestWeightForReps[n]!.value)
        (reps: n, best: bestWeightForReps[n]!),
  ];
}
