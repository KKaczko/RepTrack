import 'package:flutter/foundation.dart';

import '../../../core/platform/rest_notifications.dart';
import '../domain/set_hints.dart';
import '../domain/workout_repository.dart';

/// Ustawia powiadomienie przerwy według aktywnego treningu w bazie: po
/// starcie aplikacji (system usuwa powiadomienia przy wymuszonym
/// zamknięciu) i po przywróceniu kopii (przerwa może pochodzić z kopii).
/// Błędy powiadomień nie blokują aplikacji.
Future<void> restoreRestNotification(
  WorkoutRepository workouts,
  RestNotifications notifications,
  DateTime nowUtc,
) async {
  try {
    final session = await workouts.findActive();
    final endsAt = session?.restEndsAt;
    if (session == null || endsAt == null || !endsAt.isAfter(nowUtc)) return;
    await notifications.startRest(
      endsAt: endsAt,
      nextName: nextExerciseToDo(session, null)?.exerciseNameSnapshot ?? '',
    );
  } on Object catch (error, stack) {
    FlutterError.reportError(
      FlutterErrorDetails(exception: error, stack: stack, library: 'reptrack'),
    );
  }
}
