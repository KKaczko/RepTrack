import 'package:collection/collection.dart';

import '../../../core/domain/text_normalize.dart';
import 'exercise.dart';

/// Ćwiczenia zastępcze (ADR 0016): gdy sprzęt jest zajęty, ćwiczenie
/// zamienia się na podobne. Przypięte przez użytkownika są pierwsze,
/// potem automatyczne propozycje według mięśni, ruchu i sprzętu.

/// Powód propozycji do pokazania przy zamienniku.
enum SubstituteReason {
  /// Wspólne mięśnie główne.
  sameMuscles,

  /// Ten sam kierunek siły (pchanie, przyciąganie, statyczne).
  sameMovement,

  /// Inny sprzęt niż w zastępowanym ćwiczeniu.
  otherEquipment,

  /// Ćwiczenie było już w historii treningów.
  doneBefore,
}

/// Zamiennik z informacją, czy jest przypięty, i powodami propozycji.
typedef Substitute = ({
  Exercise exercise,
  bool pinned,
  Set<SubstituteReason> reasons,
});

/// Para przypiętych zamienników; działa w obie strony.
typedef SubstitutePin = ({String exerciseId, String substituteId});

/// Id przypiętych zamienników ćwiczenia [exerciseId] w kolejności pinów.
List<String> pinnedFor(String exerciseId, Iterable<SubstitutePin> pins) => [
  for (final pin in pins)
    if (pin.exerciseId == exerciseId)
      pin.substituteId
    else if (pin.substituteId == exerciseId)
      pin.exerciseId,
];

/// Grupa kategorii: siłowe razem, cardio i mobilność osobno.
int _categoryGroup(ExerciseCategory category) => switch (category) {
  ExerciseCategory.cardio => 1,
  ExerciseCategory.mobility => 2,
  _ => 0,
};

/// Zamienniki ćwiczenia [target]: najpierw przypięte ([pinned]), potem do
/// [limit] propozycji z tą samą grupą kategorii i co najmniej jednym
/// wspólnym mięśniem głównym, od najbardziej podobnych. [used] to id
/// ćwiczeń z historii (lekka premia: znane ćwiczenia).
List<Substitute> suggestSubstitutes(
  Exercise target,
  Iterable<Exercise> catalog, {
  List<String> pinned = const [],
  Set<String> used = const {},
  int limit = 12,
}) {
  final byId = {for (final e in catalog) e.id: e};
  Set<SubstituteReason> reasonsFor(Exercise e) => {
    if (e.primaryMuscles.any(target.primaryMuscles.contains))
      SubstituteReason.sameMuscles,
    if (target.force != null && e.force == target.force)
      SubstituteReason.sameMovement,
    if (e.equipment != target.equipment) SubstituteReason.otherEquipment,
    if (used.contains(e.id)) SubstituteReason.doneBefore,
  };

  final pinnedResult = <Substitute>[
    for (final id in pinned.toSet())
      if (byId[id] case final e? when e.id != target.id && !e.isArchived)
        (exercise: e, pinned: true, reasons: reasonsFor(e)),
  ];
  final pinnedIds = {for (final s in pinnedResult) s.exercise.id};

  final targetPrimary = target.primaryMuscles.toSet();
  final targetSecondary = target.secondaryMuscles.toSet();
  final scored = <({Exercise exercise, double score})>[];
  for (final e in catalog) {
    if (e.id == target.id || e.isArchived || pinnedIds.contains(e.id)) {
      continue;
    }
    if (_categoryGroup(e.category) != _categoryGroup(target.category)) {
      continue;
    }
    final primary = e.primaryMuscles.toSet();
    final shared = primary.intersection(targetPrimary);
    if (shared.isEmpty) continue;
    final jaccard = shared.length / primary.union(targetPrimary).length;
    final secondary = e.secondaryMuscles.toSet();
    final sharedSecondary = secondary.intersection(targetSecondary).length;
    final secondaryScore = targetSecondary.isEmpty
        ? 0.0
        : sharedSecondary / targetSecondary.length;
    final sameMeasurement =
        e.measurement.weight == target.measurement.weight &&
        e.measurement.reps == target.measurement.reps;
    final score =
        40 * jaccard +
        10 * secondaryScore +
        (target.force != null && e.force == target.force ? 15 : 0) +
        (target.mechanic != null && e.mechanic == target.mechanic ? 10 : 0) +
        (sameMeasurement ? 10 : 0) +
        (e.equipment != target.equipment ? 10 : 0) +
        (used.contains(e.id) ? 8 : 0);
    scored.add((exercise: e, score: score));
  }
  scored.sort((a, b) {
    final byScore = b.score.compareTo(a.score);
    return byScore != 0
        ? byScore
        : normalizeForSearch(a.exercise.name)
              .compareTo(normalizeForSearch(b.exercise.name));
  });
  return [
    ...pinnedResult,
    for (final s in scored.take(limit))
      (exercise: s.exercise, pinned: false, reasons: reasonsFor(s.exercise)),
  ];
}

/// Filtry listy zamienników (przypięte i propozycje pokazywane osobno).
extension SubstituteLists on List<Substitute> {
  List<Substitute> get pinnedOnly => [
    for (final s in this)
      if (s.pinned) s,
  ];

  List<Substitute> get suggestedOnly => [
    for (final s in this)
      if (!s.pinned) s,
  ];

  Substitute? byExerciseId(String id) =>
      firstWhereOrNull((s) => s.exercise.id == id);
}
