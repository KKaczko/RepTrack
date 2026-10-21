import 'package:flutter_test/flutter_test.dart';
import 'package:reptrack/features/templates/domain/template.dart';
import 'package:reptrack/features/templates/domain/template_editing.dart';
import 'package:reptrack/features/workout/domain/session_builder.dart';
import 'package:reptrack/features/workout/domain/session_editing.dart';
import 'package:reptrack/features/workout/domain/set_hints.dart';
import 'package:reptrack/features/workout/domain/template_sync.dart';
import 'package:reptrack/features/workout/domain/workout_session.dart';

import '../../../support/fakes.dart';
import '../../../support/workout_fixtures.dart';

/// „Push A” z ławką (4 serie) i podciąganiem (3 serie) w superserii.
Template _supersetTemplate() {
  final template = pushTemplate();
  return template.copyWith(
    exercises: [for (final e in template.exercises) e.copyWith(groupId: 'g')],
  );
}

WorkoutSession _session(Template template) => buildSessionFromTemplate(
  template: template,
  exercises: catalog,
  ids: SequentialIds('s'),
  startedAt: DateTime.utc(2026, 10, 19, 16),
  timeZone: 'Europe/Warsaw',
);

/// Zatwierdza najbliższą otwartą serię ćwiczenia [index].
WorkoutSession _done(WorkoutSession session, int index) {
  final exercise = sortedExercises(session)[index];
  final set = nextOpenSet(exercise)!;
  return updateSet(
    session,
    exercise.id,
    set.id,
    (s) => s.copyWith(
      weightG: 80000,
      reps: 10,
      completedAt: DateTime.utc(2026, 10, 19, 16, 5),
    ),
  );
}

void main() {
  group('kolej w superserii', () {
    test('na zmianę: A1, A2, a przerwa dopiero po rundzie', () {
      var session = _session(_supersetTemplate());
      final [bench, pull] = sortedExercises(session);

      expect(supersetTurn(session, bench.id)?.id, bench.id);
      session = _done(session, 0);
      expect(supersetTurn(session, bench.id)?.id, pull.id);
      expect(supersetRoundContinues(session, bench.id), isTrue);

      session = _done(session, 1);
      expect(supersetTurn(session, pull.id)?.id, bench.id);
      expect(supersetRoundContinues(session, pull.id), isFalse);
    });

    test('nierówna liczba serii: po końcu jednego zostaje drugie', () {
      var session = _session(_supersetTemplate());
      final [bench, pull] = sortedExercises(session);
      for (var round = 0; round < 3; round++) {
        session = _done(_done(session, 0), 1);
      }
      // Podciąganie skończone (3 serie), ławce została czwarta.
      expect(supersetTurn(session, pull.id)?.id, bench.id);
      session = _done(session, 0);
      expect(supersetTurn(session, bench.id), isNull);
      expect(supersetRoundContinues(session, bench.id), isFalse);
    });

    test('ćwiczenie poza superserią: brak kolei', () {
      final session = _session(pushTemplate());
      final bench = sortedExercises(session).first;

      expect(supersetTurn(session, bench.id), isNull);
      expect(supersetRoundContinues(session, bench.id), isFalse);
    });
  });

  group('edycja superserii w treningu', () {
    test('łączenie, odłączenie i rozpad po zmianie kolejności', () {
      var session = _session(pushTemplate());
      final [bench, pull] = sortedExercises(session);
      final ids = SequentialIds('g');

      session = linkExerciseWithNext(session, bench.id, ids);
      final linked = sortedExercises(session);
      expect(linked[0].groupId, isNotNull);
      expect(linked[1].groupId, linked[0].groupId);

      session = unlinkExercise(session, pull.id, ids);
      expect(sortedExercises(session).map((e) => e.groupId), [null, null]);

      session = linkExerciseWithNext(session, bench.id, ids);
      session = addExercisesToSession(session, [pushUp], ids);
      session = moveExerciseInSession(session, 0, 2);
      // Ławka za pompkami: grupa nie jest już ciągła.
      expect(sortedExercises(session).map((e) => e.groupId), [
        null,
        null,
        null,
      ]);
    });
  });

  group('edycja superserii w szablonie', () {
    test('łączenie, usunięcie ćwiczenia i rozłączenie', () {
      final ids = SequentialIds('g');
      var template = linkTemplateExerciseWithNext(
        pushTemplate(),
        'te-bench',
        ids,
      );
      expect(template.exercises.map((e) => e.groupId).toSet(), hasLength(1));
      expect(template.exercises.first.groupId, isNotNull);

      final removed = removeExercise(template, 'te-pull');
      expect(removed.exercises.single.groupId, isNull);

      template = unlinkTemplateExercise(template, 'te-bench', ids);
      expect(template.exercises.map((e) => e.groupId), [null, null]);
    });
  });

  group('zaktualizuj szablon po treningu', () {
    test('superseria z treningu trafia do szablonu', () {
      final template = pushTemplate();
      var session = _session(template);
      session = linkExerciseWithNext(
        session,
        sortedExercises(session).first.id,
        SequentialIds('g'),
      );

      expect(
        diffSessionAgainstTemplate(template, session),
        contains(isA<SupersetsChanged>()),
      );
      final updated = applySessionToTemplate(
        template,
        session,
        SequentialIds('n'),
      );
      final groups = updated.exercises.map((e) => e.groupId).toList();
      expect(groups.first, isNotNull);
      expect(groups.last, groups.first);
    });

    test('bez zmian w superseriach: brak zmiany', () {
      final template = _supersetTemplate();

      expect(
        diffSessionAgainstTemplate(template, _session(template)),
        isNot(contains(isA<SupersetsChanged>())),
      );
    });
  });
}
