import 'package:collection/collection.dart';

import '../../../core/domain/exercise_groups.dart';
import '../../../core/domain/ids.dart';
import '../../../core/domain/training.dart';
import '../../exercises/domain/exercise.dart';
import 'set_plan.dart';
import 'template.dart';

/// Domyślna liczba serii nowego ćwiczenia w szablonie.
const defaultSetCount = 3;

/// Domyślny zakres powtórzeń nowego ćwiczenia mierzącego powtórzenia.
const defaultRepsRange = (min: 8, max: 12);

/// Domyślny zakres czasu (s) nowego ćwiczenia mierzącego tylko czas.
const defaultDurationRange = (min: 30, max: 60);

/// Problem z poprawnością szablonu.
enum TemplateProblem { emptyName, invalidTarget, noSets }

/// Tworzy ćwiczenie szablonu z rozsądnymi wartościami domyślnymi:
///
/// * powtórzenia: 3 × 8–12,
/// * tylko czas (np. deska): 3 × 30–60 s,
/// * kardio: 1 seria na czas, bez celu,
/// * pozostałe (np. spacer farmera: ciężar i dystans): 3 serie bez celu.
TemplateExercise newTemplateExercise(
  Exercise exercise, {
  required int position,
  required IdGenerator ids,
}) {
  final m = exercise.measurement;
  final isCardio = exercise.category == ExerciseCategory.cardio;
  final (kind, min, max, sets) = switch (m) {
    _ when m.reps => (
      TargetKind.reps,
      defaultRepsRange.min,
      defaultRepsRange.max,
      defaultSetCount,
    ),
    _ when isCardio => (TargetKind.duration, null, null, 1),
    _ when m.duration && !m.distance => (
      TargetKind.duration,
      defaultDurationRange.min,
      defaultDurationRange.max,
      defaultSetCount,
    ),
    _ => (TargetKind.duration, null, null, defaultSetCount),
  };
  return TemplateExercise(
    id: ids.newId(),
    exerciseId: exercise.id,
    position: position,
    targetKind: kind,
    targetMin: min,
    targetMax: max,
    sets: [
      for (var i = 0; i < sets; i++) TemplateSet(id: ids.newId(), position: i),
    ],
  );
}

/// Dodaje ćwiczenia na koniec szablonu, w podanej kolejności.
Template addExercises(
  Template template,
  Iterable<Exercise> exercises,
  IdGenerator ids,
) {
  final current = _sorted(template);
  return template.copyWith(
    exercises: [
      ...current,
      for (final (i, exercise) in exercises.indexed)
        newTemplateExercise(exercise, position: current.length + i, ids: ids),
    ],
  );
}

/// Usuwa ćwiczenie o identyfikatorze [templateExerciseId]. Superseria,
/// która zostaje z jednym ćwiczeniem, się rozpada.
Template removeExercise(Template template, String templateExerciseId) =>
    template.copyWith(
      exercises: _normalizeGroups(
        _renumber(
          _sorted(template).where((e) => e.id != templateExerciseId).toList(),
        ),
      ),
    );

/// Zastępuje ćwiczenie o tym samym `id` nową wersją.
Template replaceExercise(Template template, TemplateExercise updated) =>
    template.copyWith(
      exercises: [
        for (final e in _sorted(template)) e.id == updated.id ? updated : e,
      ],
    );

/// Przenosi ćwiczenie z indeksu [from] na docelowy indeks [to] w liście po
/// przeniesieniu (semantyka `ReorderableListView.onReorderItem`).
Template moveExercise(Template template, int from, int to) {
  final list = _sorted(template);
  RangeError.checkValidIndex(from, list, 'from');
  RangeError.checkValidIndex(to, list, 'to');
  final moved = list.removeAt(from);
  list.insert(to, moved);
  return template.copyWith(exercises: _normalizeGroups(_renumber(list)));
}

/// Łączy ćwiczenie [templateExerciseId] z następnym w superserię
/// (ADR 0018).
Template linkTemplateExerciseWithNext(
  Template template,
  String templateExerciseId,
  IdGenerator ids,
) => _changeGroups(
  template,
  templateExerciseId,
  (groupIds, index) => linkWithNext(groupIds, index, ids.newId),
);

/// Odłącza ćwiczenie [templateExerciseId] od superserii.
Template unlinkTemplateExercise(
  Template template,
  String templateExerciseId,
  IdGenerator ids,
) => _changeGroups(
  template,
  templateExerciseId,
  (groupIds, index) => unlinkAt(groupIds, index, ids.newId),
);

Template _changeGroups(
  Template template,
  String templateExerciseId,
  List<String?> Function(List<String?> groupIds, int index) change,
) {
  final list = _sorted(template);
  final index = list.indexWhere((e) => e.id == templateExerciseId);
  if (index < 0) return template;
  return template.copyWith(
    exercises: _withGroupIds(
      list,
      change([for (final e in list) e.groupId], index),
    ),
  );
}

List<TemplateExercise> _normalizeGroups(List<TemplateExercise> list) =>
    _withGroupIds(list, normalizeGroupIds([for (final e in list) e.groupId]));

List<TemplateExercise> _withGroupIds(
  List<TemplateExercise> list,
  List<String?> groupIds,
) => [
  for (final (i, e) in list.indexed)
    e.groupId == groupIds[i] ? e : e.copyWith(groupId: groupIds[i]),
];

/// Kopia szablonu z nowymi identyfikatorami wszystkich rekordów. Grupy
/// superserii zachowują powiązania pod nowymi identyfikatorami.
Template duplicateTemplate(
  Template template,
  IdGenerator ids, {
  required String name,
}) {
  final groups = <String, String>{};
  return Template(
    id: ids.newId(),
    name: name,
    description: template.description,
    exercises: [
      for (final e in _sorted(template))
        e.copyWith(
          id: ids.newId(),
          groupId: e.groupId == null
              ? null
              : groups.putIfAbsent(e.groupId!, ids.newId),
          sets: [for (final s in e.sets) s.copyWith(id: ids.newId())],
        ),
    ],
  );
}

/// Lista problemów szablonu; pusta oznacza szablon gotowy do zapisu.
List<TemplateProblem> validateTemplate(Template template) {
  final problems = <TemplateProblem>[];
  if (template.name.trim().isEmpty) problems.add(TemplateProblem.emptyName);
  for (final exercise in template.exercises) {
    if (exercise.sets.isEmpty) {
      problems.add(TemplateProblem.noSets);
      break;
    }
  }
  final targetsValid = template.exercises.every((exercise) {
    try {
      validateTarget(exercise.targetMin, exercise.targetMax);
      for (final set in exercise.sets) {
        validateTarget(set.targetMin, set.targetMax);
      }
      return true;
    } on InvalidTargetException {
      return false;
    }
  });
  if (!targetsValid) problems.add(TemplateProblem.invalidTarget);
  return problems;
}

/// Łączna liczba serii w szablonie.
int totalSets(Template template) =>
    template.exercises.fold(0, (sum, e) => sum + e.setCount);

List<TemplateExercise> _sorted(Template template) =>
    template.exercises.sortedBy<num>((e) => e.position);

List<TemplateExercise> _renumber(List<TemplateExercise> list) => [
  for (final (i, e) in list.indexed)
    e.position == i ? e : e.copyWith(position: i),
];
