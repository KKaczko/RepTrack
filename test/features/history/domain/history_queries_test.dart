import 'package:flutter_test/flutter_test.dart';
import 'package:reptrack/core/domain/local_date.dart';
import 'package:reptrack/features/history/domain/history_queries.dart';
import 'package:reptrack/features/history/domain/session_corrections.dart';
import 'package:reptrack/features/workout/domain/session_editing.dart';

import '../../../support/fakes.dart';
import '../../../support/workout_fixtures.dart';

void main() {
  // Historia od najnowszej, jak w repozytorium.
  final oct19 = finishedPush('c', DateTime.utc(2026, 10, 19, 16), [
    (85000, 8),
    (85000, 7),
  ]);
  final oct12 = finishedPush('b', DateTime.utc(2026, 10, 12, 16), [
    (80000, 10),
    (80000, 9),
  ]);
  final oct05 = finishedPush('a', DateTime.utc(2026, 10, 5, 16), [(75000, 10)]);
  final history = [oct19, oct12, oct05];

  test('wykonania ćwiczenia od najnowszego', () {
    final performances = exercisePerformances(history, 'bench');
    expect(
      [for (final p in performances) p.session.id],
      [oct19.id, oct12.id, oct05.id],
    );
    expect(exercisePerformances(history, 'plank'), isEmpty);
  });

  test('poprzednie wykonanie to ostatni wcześniejszy trening', () {
    expect(previousPerformance(history, 'bench', oct19)!.session.id, oct12.id);
    expect(previousPerformance(history, 'bench', oct12)!.session.id, oct05.id);
    expect(previousPerformance(history, 'bench', oct05), isNull);
  });

  test('porównanie z poprzednim: objętość i szacowany 1RM', () {
    final rows = compareWithPrevious(oct19, history);
    final bench = rows.first;
    expect(bench.current.exerciseId, 'bench');
    expect(bench.volumeG, 85000 * 15);
    expect(bench.previousVolumeG, 80000 * 19);
    expect(bench.bestE1rmG, closeTo(85000 * (1 + 8 / 30), 0.01));
    expect(bench.previousBestE1rmG, closeTo(80000 * (1 + 10 / 30), 0.01));
  });

  test('treningi w tygodniu od poniedziałku, od najstarszego', () {
    final weeks = workoutsPerWeek(
      history,
      const LocalDate(2026, 10, 21),
      weeks: 4,
    );
    expect(
      [for (final w in weeks) w.weekStart],
      [
        const LocalDate(2026, 9, 28),
        const LocalDate(2026, 10, 5),
        const LocalDate(2026, 10, 12),
        const LocalDate(2026, 10, 19),
      ],
    );
    expect([for (final w in weeks) w.count], [0, 1, 1, 1]);
  });

  test('szablony od ostatnio użytego, bez powtórzeń', () {
    expect(templatesByLastUse(history), ['tpl']);
    expect(templatesByLastUse(const []), isEmpty);
  });

  group('korekty', () {
    test('dopisana seria jest zatwierdzona z wartościami ostatniej', () {
      final bench = sortedExercises(oct12).first;
      final next = appendLoggedSet(oct12, bench.id, SequentialIds('n'));
      final sets = sortedSets(
        next.exercises.firstWhere((e) => e.id == bench.id),
      );
      expect(sets, hasLength(5));
      expect((sets.last.weightG, sets.last.reps), (null, null));
      expect(sets.last.completedAt, oct12.endedAt);
    });

    test('zatwierdzenie przy korekcie zachowuje czas, cofnięcie go czyści', () {
      final set = sortedSets(sortedExercises(oct12).first)[1];
      expect(setLogged(set, oct12, logged: true).completedAt, set.completedAt);
      expect(setLogged(set, oct12, logged: false).completedAt, isNull);
      final open = sortedSets(sortedExercises(oct12).first)[3];
      expect(setLogged(open, oct12, logged: true).completedAt, oct12.endedAt);
    });
  });
}
