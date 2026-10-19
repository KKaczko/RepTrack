import 'package:collection/collection.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../core/domain/ids.dart';
import '../../../core/domain/training.dart';
import 'template.dart';

part 'set_plan.freezed.dart';

/// Efektywny plan jednej serii po zastosowaniu dziedziczenia.
@freezed
abstract class EffectiveSet with _$EffectiveSet {
  const factory EffectiveSet({
    required String templateSetId,
    required int index,
    required SetType setType,
    required TargetKind targetKind,
    int? targetMin,
    int? targetMax,
    int? targetWeightG,
    int? restSeconds,
    @Default(false) bool overridesSetType,
    @Default(false) bool overridesTarget,
    @Default(false) bool overridesWeight,
    @Default(false) bool overridesRest,
  }) = _EffectiveSet;
}

/// Pola serii, które można nadpisać i przywrócić do dziedziczenia.
enum SetField { setType, target, weight, rest }

/// Niepoprawny zakres celu (min > max albo wartość ujemna).
final class InvalidTargetException implements Exception {
  const InvalidTargetException(this.min, this.max);

  final int? min;
  final int? max;

  @override
  String toString() => 'InvalidTargetException($min, $max)';
}

/// Liczy efektywny plan serii ćwiczenia: każde pole serii równe null
/// dziedziczy wartość z [exercise]. Serie są zwracane w kolejności `position`.
///
/// „3 × 8–12” to trzy serie bez nadpisań. Piramida 12–15 / 10–12 / 8–10 / 6–8
/// to cztery serie z nadpisanym zakresem.
List<EffectiveSet> resolveEffectiveSets(TemplateExercise exercise) {
  final sorted = exercise.sets.sortedBy<num>((s) => s.position);
  return [
    for (final (index, set) in sorted.indexed)
      EffectiveSet(
        templateSetId: set.id,
        index: index,
        setType: set.setType ?? exercise.defaultSetType,
        targetKind: exercise.targetKind,
        targetMin: set.overridesTarget ? set.targetMin : exercise.targetMin,
        targetMax: set.overridesTarget ? set.targetMax : exercise.targetMax,
        targetWeightG: set.targetWeightG ?? exercise.targetWeightG,
        restSeconds: set.restSeconds ?? exercise.restSeconds,
        overridesSetType: set.setType != null,
        overridesTarget: set.overridesTarget,
        overridesWeight: set.targetWeightG != null,
        overridesRest: set.restSeconds != null,
      ),
  ];
}

/// Sprawdza zakres celu. Pusty cel (oba null) jest dozwolony.
void validateTarget(int? min, int? max) {
  if (min == null && max == null) return;
  if ((min != null && min < 0) || (max != null && max < 0)) {
    throw InvalidTargetException(min, max);
  }
  if (min != null && max != null && min > max) {
    throw InvalidTargetException(min, max);
  }
}

/// Zmienia liczbę serii. Nowe serie dziedziczą wszystko (pola null), a przy
/// zmniejszaniu usuwane są ostatnie serie. Liczba serii musi być ≥ 1.
TemplateExercise withSetCount(
  TemplateExercise exercise,
  int count,
  IdGenerator ids,
) {
  if (count < 1) {
    throw ArgumentError.value(count, 'count', 'Liczba serii musi być ≥ 1');
  }
  final sorted = exercise.sets.sortedBy<num>((s) => s.position);
  final List<TemplateSet> result;
  if (count <= sorted.length) {
    result = sorted.take(count).toList();
  } else {
    result = [
      ...sorted,
      for (var i = sorted.length; i < count; i++)
        TemplateSet(id: ids.newId(), position: i),
    ];
  }
  return exercise.copyWith(sets: _renumber(result));
}

/// Nadpisuje wybrane pola serii o indeksie [index]. Pola pominięte zostają
/// bez zmian; aby przywrócić dziedziczenie, użyj [restoreInheritance].
TemplateExercise overrideSet(
  TemplateExercise exercise,
  int index, {
  SetType? setType,
  ({int? min, int? max})? target,
  int? targetWeightG,
  int? restSeconds,
}) {
  if (target != null) validateTarget(target.min, target.max);
  return _updateSet(exercise, index, (set) {
    return set.copyWith(
      setType: setType ?? set.setType,
      targetMin: target != null ? target.min : set.targetMin,
      targetMax: target != null ? target.max : set.targetMax,
      targetWeightG: targetWeightG ?? set.targetWeightG,
      restSeconds: restSeconds ?? set.restSeconds,
    );
  });
}

/// Przywraca dziedziczenie wskazanych pól serii (domyślnie wszystkich).
TemplateExercise restoreInheritance(
  TemplateExercise exercise,
  int index, {
  Set<SetField> fields = const {...SetField.values},
}) {
  return _updateSet(exercise, index, (set) {
    return set.copyWith(
      setType: fields.contains(SetField.setType) ? null : set.setType,
      targetMin: fields.contains(SetField.target) ? null : set.targetMin,
      targetMax: fields.contains(SetField.target) ? null : set.targetMax,
      targetWeightG: fields.contains(SetField.weight)
          ? null
          : set.targetWeightG,
      restSeconds: fields.contains(SetField.rest) ? null : set.restSeconds,
    );
  });
}

TemplateExercise _updateSet(
  TemplateExercise exercise,
  int index,
  TemplateSet Function(TemplateSet set) update,
) {
  final sorted = exercise.sets.sortedBy<num>((s) => s.position);
  RangeError.checkValidIndex(index, sorted, 'index');
  final updated = [
    for (final (i, set) in sorted.indexed) i == index ? update(set) : set,
  ];
  return exercise.copyWith(sets: _renumber(updated));
}

List<TemplateSet> _renumber(List<TemplateSet> sets) => [
  for (final (i, set) in sets.indexed)
    set.position == i ? set : set.copyWith(position: i),
];
