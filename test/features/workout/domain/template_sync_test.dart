import 'package:flutter_test/flutter_test.dart';
import 'package:reptrack/features/templates/domain/set_plan.dart';
import 'package:reptrack/features/workout/domain/session_builder.dart';
import 'package:reptrack/features/workout/domain/session_editing.dart';
import 'package:reptrack/features/workout/domain/template_sync.dart';
import 'package:reptrack/features/workout/domain/workout_session.dart';

import '../../../support/fakes.dart';
import '../../../support/workout_fixtures.dart';

WorkoutSession _session() => buildSessionFromTemplate(
  template: pushTemplate(),
  exercises: catalog,
  ids: SequentialIds('s'),
  startedAt: DateTime.utc(2026, 10, 19, 16),
  timeZone: 'Europe/Warsaw',
);

void main() {
  test('bez zmian w strukturze nie ma różnic', () {
    expect(diffSessionAgainstTemplate(pushTemplate(), _session()), isEmpty);
  });

  test('dodane serie i ćwiczenia, usunięte ćwiczenie, kolejność', () {
    var session = _session();
    final benchId = session.exercises.first.id;
    session = addSet(session, benchId, SequentialIds('a'));
    session = addExercisesToSession(session, [plank], SequentialIds('b'));
    session = removeExerciseFromSession(session, session.exercises[1].id);
    session = moveExerciseInSession(session, 1, 0);

    final changes = diffSessionAgainstTemplate(pushTemplate(), session);

    expect(changes.whereType<ExerciseAdded>().single.name, 'Deska');
    final sets = changes.whereType<SetCountChanged>().single;
    expect((sets.from, sets.to), (4, 5));
    expect(changes.whereType<ExerciseRemoved>().single.exerciseId, 'pullup');
    expect(
      changes.whereType<OrderChanged>(),
      isEmpty,
      reason: 'zostało jedno ćwiczenie z szablonu, kolejność bez zmian',
    );
  });

  test('zmiana kolejności ćwiczeń z szablonu', () {
    final session = moveExerciseInSession(_session(), 1, 0);

    final changes = diffSessionAgainstTemplate(pushTemplate(), session);

    expect(changes, [isA<OrderChanged>()]);
  });

  test('zastosowanie zachowuje cele i nadpisania, zmienia strukturę', () {
    var session = _session();
    session = addSet(session, session.exercises.first.id, SequentialIds('a'));
    session = addExercisesToSession(session, [plank], SequentialIds('b'));
    session = moveExerciseInSession(session, 1, 0);

    final updated = applySessionToTemplate(
      pushTemplate(),
      session,
      SequentialIds('n'),
    );

    expect(
      [for (final e in updated.exercises) e.exerciseId],
      ['pullup', 'bench', 'plank'],
    );
    expect([for (final e in updated.exercises) e.position], [0, 1, 2]);
    final benchPlan = resolveEffectiveSets(updated.exercises[1]);
    expect(benchPlan, hasLength(5));
    expect(benchPlan.first.targetWeightG, 40000, reason: 'nadpisanie zostaje');
    expect((benchPlan.last.targetMin, benchPlan.last.targetMax), (8, 12));
    expect(updated.exercises[2].setCount, 3);
    expect(updated.exercises[2].targetMin, isNull);
    // Ćwiczenia z szablonu odpowiadają treningowi; dodana w trakcie deska nie
    // ma powiązania z szablonem, więc dalej widać ją jako różnicę.
    final again = diffSessionAgainstTemplate(updated, session);
    expect(again.whereType<SetCountChanged>(), isEmpty);
    expect(again.whereType<OrderChanged>(), isEmpty);
    expect(again.whereType<ExerciseReplaced>(), isEmpty);
  });
}
