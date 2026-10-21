import 'package:flutter_test/flutter_test.dart';
import 'package:reptrack/core/domain/exercise_groups.dart';

String Function() _ids() {
  var n = 0;
  return () => 'g${++n}';
}

void main() {
  test('grupy to ciągłe odcinki co najmniej dwóch ćwiczeń', () {
    expect(exerciseGroups(['a', 'a', null, 'b', 'b', 'b', 'c']), [
      [0, 1],
      [3, 4, 5],
    ]);
    expect(exerciseGroups([null, null]), isEmpty);
  });

  test('łączenie z następnym: nowa grupa, dołączenie i scalenie', () {
    final ids = _ids();
    expect(linkWithNext([null, null, null], 0, ids), ['g1', 'g1', null]);
    expect(linkWithNext(['a', 'a', null], 1, ids), ['a', 'a', 'a']);
    expect(linkWithNext([null, 'b', 'b'], 0, ids), ['b', 'b', 'b']);
    expect(linkWithNext(['a', 'a', 'b', 'b'], 1, ids), ['a', 'a', 'a', 'a']);
    // Ostatniego nie ma z czym połączyć.
    expect(linkWithNext([null, null], 1, ids), [null, null]);
  });

  test('odłączenie: grupa dwóch się rozpada, środek dzieli na dwie', () {
    final ids = _ids();
    expect(unlinkAt(['a', 'a'], 0, ids), [null, null]);
    expect(unlinkAt(['a', 'a', 'a'], 2, ids), ['a', 'a', null]);
    expect(unlinkAt(['a', 'a', 'a', 'a', 'a'], 2, ids), [
      'a',
      'a',
      null,
      'g1',
      'g1',
    ]);
  });

  test('po zmianie kolejności niespójna grupa się rozpada', () {
    // A1 przeniesione za ćwiczenie spoza grupy.
    expect(normalizeGroupIds(['a', null, 'a']), [null, null, null]);
    expect(normalizeGroupIds(['a', 'a', null, 'a', 'a']), [
      'a',
      'a',
      null,
      null,
      null,
    ]);
    expect(normalizeGroupIds(['a', 'a', null, 'a', 'a'], newId: () => 'n'), [
      'a',
      'a',
      null,
      'n',
      'n',
    ]);
  });

  test('oznaczenia A1, A2, B1…', () {
    expect(groupLabels(['x', 'x', null, 'y', 'y', 'y']), [
      (letter: 'A', number: 1, size: 2),
      (letter: 'A', number: 2, size: 2),
      null,
      (letter: 'B', number: 1, size: 3),
      (letter: 'B', number: 2, size: 3),
      (letter: 'B', number: 3, size: 3),
    ]);
  });
}
