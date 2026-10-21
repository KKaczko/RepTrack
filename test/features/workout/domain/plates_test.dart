import 'package:flutter_test/flutter_test.dart';
import 'package:reptrack/features/workout/domain/plates.dart';

const _kg = <double>[25, 20, 15, 10, 5, 2.5, 1.25];

void _expectLoad(PlateLoad? load, List<double> perSide, double remainder) {
  expect(load, isNotNull);
  expect(load!.perSide, perSide);
  expect(load.remainder, remainder);
}

void main() {
  test('talerze na stronę od największego', () {
    _expectLoad(platesPerSide(100, 20, _kg), [25, 15], 0);
    _expectLoad(platesPerSide(82.5, 20, _kg), [25, 5, 1.25], 0);
    _expectLoad(platesPerSide(140, 20, _kg), [25, 25, 10], 0);
  });

  test('sam gryf, poniżej gryfu i reszta', () {
    _expectLoad(platesPerSide(20, 20, _kg), [], 0);
    expect(platesPerSide(15, 20, _kg), isNull);
    _expectLoad(platesPerSide(101, 20, _kg), [25, 15], 1);
  });

  test('funty i niestandardowy zestaw', () {
    _expectLoad(platesPerSide(225, 45, const [45, 35, 25, 10, 5, 2.5]), [
      45,
      45,
    ], 0);
    _expectLoad(platesPerSide(60, 20, const [10]), [10, 10], 0);
    _expectLoad(platesPerSide(65, 20, const [10]), [10, 10], 5);
  });
}
