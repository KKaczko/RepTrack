import 'package:collection/collection.dart';

import '../../../core/domain/ids.dart';
import '../../../core/domain/training.dart';
import '../../templates/domain/set_plan.dart';
import '../../templates/domain/template.dart';
import 'session_editing.dart';
import 'workout_session.dart';

/// Różnica między szablonem a treningiem (opcja „zaktualizuj szablon na
/// podstawie tego treningu”, spec. 5.3). Dotyczy struktury: ćwiczeń, ich
/// kolejności i liczby serii. Cele i ciężary szablonu zostają bez zmian.
sealed class TemplateChange {
  const TemplateChange();
}

final class ExerciseAdded extends TemplateChange {
  const ExerciseAdded(this.name);

  final String name;
}

final class ExerciseRemoved extends TemplateChange {
  const ExerciseRemoved(this.exerciseId);

  /// Id ćwiczenia z biblioteki; nazwę dobiera UI.
  final String exerciseId;
}

final class ExerciseReplaced extends TemplateChange {
  const ExerciseReplaced({required this.fromExerciseId, required this.toName});

  final String fromExerciseId;
  final String toName;
}

final class SetCountChanged extends TemplateChange {
  const SetCountChanged({
    required this.name,
    required this.from,
    required this.to,
  });

  final String name;
  final int from;
  final int to;
}

final class OrderChanged extends TemplateChange {
  const OrderChanged();
}

/// Zmiany, które zastosowanie treningu wprowadziłoby do [template].
List<TemplateChange> diffSessionAgainstTemplate(
  Template template,
  WorkoutSession session,
) {
  final byId = {for (final te in template.exercises) te.id: te};
  final kept = <String>[];
  final changes = <TemplateChange>[];
  for (final se in _usable(session)) {
    final te = se.templateExerciseId == null
        ? null
        : byId[se.templateExerciseId];
    if (te == null) {
      changes.add(ExerciseAdded(se.exerciseNameSnapshot));
      continue;
    }
    kept.add(te.id);
    if (te.exerciseId != se.exerciseId) {
      changes.add(
        ExerciseReplaced(
          fromExerciseId: te.exerciseId,
          toName: se.exerciseNameSnapshot,
        ),
      );
    }
    if (te.setCount != se.sets.length) {
      changes.add(
        SetCountChanged(
          name: se.exerciseNameSnapshot,
          from: te.setCount,
          to: se.sets.length,
        ),
      );
    }
  }
  final templateOrder = [
    for (final te in template.exercises.sortedBy<num>((e) => e.position))
      if (kept.contains(te.id)) te.id,
  ];
  if (!const ListEquality<String>().equals(templateOrder, kept)) {
    changes.add(const OrderChanged());
  }
  for (final te in template.exercises.sortedBy<num>((e) => e.position)) {
    if (!kept.contains(te.id)) changes.add(ExerciseRemoved(te.exerciseId));
  }
  return changes;
}

/// Nowa wersja szablonu o strukturze treningu. Ćwiczenia szablonu zachowują
/// cele, ciężary i nadpisania; nowe serie dziedziczą wartości wspólne.
/// Ćwiczenia dodane w treningu trafiają do szablonu bez celu.
Template applySessionToTemplate(
  Template template,
  WorkoutSession session,
  IdGenerator ids,
) {
  final byId = {for (final te in template.exercises) te.id: te};
  final exercises = <TemplateExercise>[];
  for (final se in _usable(session)) {
    final position = exercises.length;
    final te = se.templateExerciseId == null
        ? null
        : byId[se.templateExerciseId];
    if (te != null) {
      exercises.add(
        withSetCount(
          te.copyWith(exerciseId: se.exerciseId, position: position),
          se.sets.length,
          ids,
        ),
      );
    } else {
      final first = sortedSets(se).first;
      exercises.add(
        TemplateExercise(
          id: ids.newId(),
          exerciseId: se.exerciseId,
          position: position,
          targetKind: first.targetKind ?? TargetKind.reps,
          groupId: se.groupId,
          sets: [
            for (var i = 0; i < se.sets.length; i++)
              TemplateSet(id: ids.newId(), position: i),
          ],
        ),
      );
    }
  }
  return template.copyWith(exercises: exercises);
}

/// Ćwiczenia sesji z co najmniej jedną serią, w kolejności.
Iterable<SessionExercise> _usable(WorkoutSession session) =>
    sortedExercises(session).where((e) => e.sets.isNotEmpty);
