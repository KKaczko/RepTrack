import 'package:flutter_test/flutter_test.dart';
import 'package:reptrack/features/exercises/data/drift_exercise_repository.dart';
import 'package:reptrack/features/templates/data/drift_template_repository.dart';
import 'package:reptrack/features/workout/data/drift_workout_repository.dart';

import '../../support/test_database.dart';
import '../../support/workout_fixtures.dart';

void main() {
  test('obserwacja treningu nie zagłusza zmian szablonów', () async {
    final db = memoryDatabase();
    addTearDown(db.close);
    final clock = testClock();
    for (final e in catalog.values) {
      await DriftExerciseRepository(db, clock).save(e);
    }
    final templates = DriftTemplateRepository(db, clock);

    // Najpierw strumień treningu, potem szablonów: tak jak w aplikacji, gdzie
    // pasek treningu subskrybuje wcześniej niż lista szablonów.
    final workout = DriftWorkoutRepository(
      db,
      clock,
    ).watchActive().listen((_) {});
    addTearDown(workout.cancel);
    final names = templates
        .watchAll()
        .map((all) => [for (final t in all) t.name])
        .asBroadcastStream();
    expect(await names.first, isEmpty);

    final next = names.firstWhere((n) => n.isNotEmpty);
    await templates.save(pushTemplate());

    expect(await next, ['Push A']);
  });
}
