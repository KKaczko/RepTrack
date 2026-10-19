import 'package:flutter_test/flutter_test.dart';
import 'package:reptrack/app/bootstrap.dart';
import 'package:reptrack/features/exercises/data/drift_exercise_repository.dart';
import 'package:reptrack/features/templates/data/drift_template_repository.dart';
import 'package:reptrack/features/workout/data/drift_workout_repository.dart';
import 'package:reptrack/features/workout/domain/session_builder.dart';

import '../support/fake_devices.dart';
import '../support/fakes.dart';
import '../support/test_database.dart';
import '../support/workout_fixtures.dart';

void main() {
  test('trwająca przerwa wraca do powiadomień po restarcie', () async {
    final db = memoryDatabase();
    addTearDown(db.close);
    final clock = testClock();
    for (final e in catalog.values) {
      await DriftExerciseRepository(db, clock).save(e);
    }
    await DriftTemplateRepository(db, clock).save(pushTemplate());
    final now = DateTime.fromMillisecondsSinceEpoch(
      DateTime.now().millisecondsSinceEpoch,
      isUtc: true,
    );
    final endsAt = now.add(const Duration(seconds: 90));
    await DriftWorkoutRepository(db, clock).save(
      buildSessionFromTemplate(
        template: pushTemplate(),
        exercises: catalog,
        ids: SequentialIds('s'),
        startedAt: now.subtract(const Duration(minutes: 10)),
        timeZone: 'Europe/Warsaw',
      ).copyWith(restEndsAt: endsAt),
    );
    final notifications = FakeRestNotifications();

    await restoreRestNotification(db, notifications);

    expect(notifications.endsAt, endsAt);
    expect(notifications.nextName, 'Wyciskanie');
  });

  test('zakończona przerwa nie wraca', () async {
    final db = memoryDatabase();
    addTearDown(db.close);
    final clock = testClock();
    for (final e in catalog.values) {
      await DriftExerciseRepository(db, clock).save(e);
    }
    final now = DateTime.fromMillisecondsSinceEpoch(
      DateTime.now().millisecondsSinceEpoch,
      isUtc: true,
    );
    await DriftWorkoutRepository(db, clock).save(
      buildEmptySession(
        ids: SequentialIds('s'),
        startedAt: now.subtract(const Duration(minutes: 10)),
        timeZone: 'Europe/Warsaw',
      ).copyWith(restEndsAt: now.subtract(const Duration(seconds: 5))),
    );
    final notifications = FakeRestNotifications();

    await restoreRestNotification(db, notifications);

    expect(notifications.endsAt, isNull);
  });
}
