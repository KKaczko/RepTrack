import 'package:collection/collection.dart';

import '../../../core/domain/exercise_groups.dart';
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

/// Superserie treningu różnią się od szablonu (ADR 0018).
final class SupersetsChanged extends TemplateChange {
  const SupersetsChanged();
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
  if (!_sameSupersets(template, session)) {
    changes.add(const SupersetsChanged());
  }
  return changes;
}

/// Te same superserie: grupy ćwiczeń (po id ćwiczenia szablonu, a dla
/// dodanych w treningu po id ćwiczenia sesji), bez względu na kolejność.
bool _sameSupersets(Template template, WorkoutSession session) {
  final templateList = template.exercises.sortedBy<num>((e) => e.position);
  final sessionList = _usable(session).toList();
  Set<Set<String>> groups(List<String?> groupIds, List<String> keys) => {
    for (final group in exerciseGroups(groupIds))
      {for (final i in group) keys[i]},
  };
  return const DeepCollectionEquality.unordered().equals(
    groups(
      [for (final te in templateList) te.groupId],
      [for (final te in templateList) te.id],
    ),
    groups(
      [for (final se in sessionList) se.groupId],
      [for (final se in sessionList) se.templateExerciseId ?? se.id],
    ),
  );
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
          te.copyWith(
            exerciseId: se.exerciseId,
            position: position,
            groupId: se.groupId,
          ),
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
  // Superserie jak w treningu; ćwiczenie bez serii mogło rozdzielić grupę.
  final groupIds = normalizeGroupIds([
    for (final e in exercises) e.groupId,
  ], newId: ids.newId);
  return template.copyWith(
    exercises: [
      for (final (i, e) in exercises.indexed)
        e.groupId == groupIds[i] ? e : e.copyWith(groupId: groupIds[i]),
    ],
  );
}

/// Ćwiczenia sesji z co najmniej jedną serią, w kolejności.
Iterable<SessionExercise> _usable(WorkoutSession session) =>
    sortedExercises(session).where((e) => e.sets.isNotEmpty);
