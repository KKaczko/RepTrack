import 'package:flutter_test/flutter_test.dart';
import 'package:reptrack/core/domain/local_date.dart';
import 'package:reptrack/core/domain/training.dart';
import 'package:reptrack/features/exercises/domain/exercise.dart';
import 'package:reptrack/features/workout/domain/session_builder.dart';
import 'package:reptrack/features/workout/domain/workout_session.dart';

import '../../../support/fakes.dart';
import '../../../support/workout_fixtures.dart';

void main() {
  final start = DateTime.utc(2026, 10, 19, 16, 30);

  group('buildSessionFromTemplate', () {
    final session = buildSessionFromTemplate(
      template: pushTemplate(),
      exercises: catalog,
      ids: SequentialIds('s'),
      startedAt: start,
      timeZone: 'Europe/Warsaw',
    );

    test('aktywna sesja z metadanymi szablonu i strefą', () {
      expect(session.status, SessionStatus.active);
      expect(session.templateId, 'tpl');
      expect(session.templateNameSnapshot, 'Push A');
      expect(session.title, 'Push A');
      expect(session.startedAt, start);
      expect(session.timeZone, 'Europe/Warsaw');
      expect(session.localDate, const LocalDate(2026, 10, 19));
    });

    test('kopiuje efektywny plan serii z dziedziczeniem i nadpisaniami', () {
      final benchSets = session.exercises.first.sets;

      expect(benchSets, hasLength(4));
      expect(benchSets.first.setType, SetType.warmup);
      expect((benchSets.first.targetMin, benchSets.first.targetMax), (10, 10));
      expect(benchSets.first.targetWeightG, 40000);
      expect(benchSets[1].setType, SetType.working);
      expect((benchSets[1].targetMin, benchSets[1].targetMax), (8, 12));
      expect(benchSets[1].targetWeightG, 80000);
      expect(benchSets[1].restSeconds, 150);
      expect(session.exercises[1].sets.last.setType, SetType.amrap);
      expect(benchSets.every((s) => !s.isCompleted), isTrue);
      expect(
        benchSets.every((s) => s.weightG == null && s.reps == null),
        isTrue,
      );
    });

    test('snapshot nazwy i ustawień ćwiczenia oraz powiązanie z szablonem', () {
      final pull = session.exercises[1];

      expect(pull.exerciseNameSnapshot, 'Podciąganie');
      expect(pull.loadModeSnapshot, LoadMode.weightedBodyweight);
      expect(pull.measurementSnapshot, Measurement.weightAndReps);
      expect(pull.templateExerciseId, 'te-pull');
      expect(pull.note, 'Pełny zwis');
    });

    test('trening po północy dostaje datę dnia rozpoczęcia', () {
      final late = buildSessionFromTemplate(
        template: pushTemplate(),
        exercises: catalog,
        ids: SequentialIds(),
        startedAt: DateTime.utc(2026, 10, 19, 21, 50), // 23:50 w Warszawie
        timeZone: 'Europe/Warsaw',
      );

      expect(late.localDate, const LocalDate(2026, 10, 19));
    });

    test('pomija ćwiczenia, których nie ma w katalogu', () {
      final partial = buildSessionFromTemplate(
        template: pushTemplate(),
        exercises: const {'bench': bench},
        ids: SequentialIds(),
        startedAt: start,
        timeZone: 'UTC',
      );

      expect([for (final e in partial.exercises) e.exerciseId], ['bench']);
    });
  });

  test('pusty trening', () {
    final session = buildEmptySession(
      ids: SequentialIds(),
      startedAt: start,
      timeZone: 'Europe/Warsaw',
    );

    expect(session.exercises, isEmpty);
    expect(session.templateId, isNull);
    expect(session.isActive, isTrue);
  });

  test('ćwiczenie dodane w trakcie: 3 serie bez celu, kardio 1 seria', () {
    final ids = SequentialIds();
    final b = newSessionExercise(bench, position: 0, ids: ids);
    final r = newSessionExercise(run, position: 1, ids: ids);

    expect(b.sets, hasLength(3));
    expect(b.sets.every((s) => s.targetMin == null), isTrue);
    expect(b.sets.first.targetKind, TargetKind.reps);
    expect(r.sets, hasLength(1));
    expect(r.sets.single.targetKind, TargetKind.duration);
  });
}
